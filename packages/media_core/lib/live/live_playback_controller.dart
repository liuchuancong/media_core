import 'dart:async';

import '../adapter/player_adapter_event.dart';
import '../fallback/backend_fallback.dart';
import '../fallback/line_fallback.dart';import '../identity/source_id.dart';
import '../kernel/player_handle.dart';
import '../kernel/player_kernel.dart';
import '../source/player_source.dart';
import '../source/source_headers.dart';
import 'live_playback_models.dart';
import 'live_playback_state.dart';
import 'live_watchdogs.dart';

/// A live playback request: primary URL plus fallback lines.
final class LiveSourceRequest {
  /// Creates the request.
  const LiveSourceRequest({required this.urls, this.headers = const <String, String>{}, this.title});

  /// Candidate URLs, best first. [urls].first is opened first.
  final List<String> urls;

  /// Optional HTTP headers applied to every line.
  final Map<String, String> headers;

  /// Optional display title for events.
  final String? title;
}

/// Terminal failure reported after every recovery level is
/// exhausted.
final class LivePlaybackError {
  /// Creates the error report.
  const LivePlaybackError({required this.message, required this.level, this.cause});

  /// Human readable message.
  final String message;

  /// Highest recovery level attempted.
  final LiveRecoveryLevel level;

  /// Underlying error, when there was one.
  final Object? cause;

  @override
  String toString() => 'LivePlaybackError($message, level: $level)';
}

/// Orchestrates live playback on top of a [PlayerKernel].
///
/// [LivePlaybackController] is the live-stream counterpart of the
/// kernel's on-demand recovery: non-seekable sources need
/// watchdog-inferred stalls and multi-line / multi-engine
/// fallback in addition to adapter-reported errors.
///
/// ```text
/// play(request)
///   │  PlayerKernel.create + open
///   ▼
/// LiveWatchdogs ──stall──▶ recovery ladder:
///   │                        1. same source replay
///   │                        2. line switch (LineFallback)
///   │                        3. engine switch (BackendFallback)
///   │                        4. backoff retry
///   ▼                        5. terminal → onError
/// adapter error ────────────▶
/// ```
///
/// Every step is generation-guarded: a recovery scheduled for an
/// old source generation is dropped when a newer play() arrived.
final class LivePlaybackController {
  /// Creates the controller bound to [kernel].
  LivePlaybackController(
    this.kernel, {
    LiveWatchdogs? watchdogs,
    this.backoffDelays = const <Duration>[
      Duration(milliseconds: 750),
      Duration(seconds: 2),
    ],
    this.maxSameEngineRecoveryAttempts = 1,
  }) : watchdogs = watchdogs ?? LiveWatchdogs() {
    _wireWatchdogs();
  }

  /// The kernel providing players and adapters.
  final PlayerKernel kernel;

  /// Watchdog bundle inferring stalls.
  final LiveWatchdogs watchdogs;

  /// Backoff schedule after immediate recovery exhausted.
  final List<Duration> backoffDelays;

  /// Bounded same-engine (source replay) attempts per failure.
  final int maxSameEngineRecoveryAttempts;

  PlayerHandle? _handle;
  StreamSubscription<Object?>? _eventSub;

  int _generation = 0;
  bool _playbackRequested = false;

  LiveSourceRequest? _request;
  String? _currentUrl;
  int _sameEngineAttempts = 0;
  int _backoffAttempt = 0;
  Timer? _backoffTimer;

  final BackendFallback _engineFallback = BackendFallback();
  final LineFallback _lineFallback = LineFallback();

  final _stateController = StreamController<LivePlaybackState>.broadcast();
  final _errorController = StreamController<LivePlaybackError>.broadcast();

  /// Playback state stream.
  Stream<LivePlaybackState> get onStateChanged => _stateController.stream;

  /// Terminal error stream.
  Stream<LivePlaybackError> get onError => _errorController.stream;

  /// Current playback state.
  LivePlaybackState state = LivePlaybackState.idle;

  /// The active player handle, when one exists.
  PlayerHandle? get handle => _handle;

  /// Current backend id, when a handle exists.
  String? get backendId => _handle?.backendId;

  /// Candidate URLs of the active request.
  List<String> get lines => _request?.urls ?? const <String>[];

  /// Index of the line currently played.
  int get lineIndex {
    final urls = lines;
    final index = urls.indexOf(_currentUrl ?? '');
    return index < 0 ? 0 : index;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts playing [request].
  ///
  /// Replaces any previous source; recovery state resets.
  Future<void> play(LiveSourceRequest request) {
    _request = request;
    _playbackRequested = true;
    _sameEngineAttempts = 0;
    _backoffAttempt = 0;
    _cancelBackoff();
    final generation = ++_generation;
    return _open(generation, request.urls.first);
  }

  /// Switches to line [index] of the current request.
  Future<void> switchLine(int index) {
    final urls = lines;
    if (index < 0 || index >= urls.length) return Future<void>.value();
    final generation = _generation;
    return _open(generation, urls[index]);
  }

  /// Replays the current source from scratch.
  Future<void> retry() {
    final url = _currentUrl;
    if (url == null || _request == null) return Future<void>.value();
    _playbackRequested = true;
    _sameEngineAttempts = 0;
    _backoffAttempt = 0;
    _cancelBackoff();
    final generation = ++_generation;
    return _open(generation, url);
  }

  /// Pauses playback (a user intent — watchdogs stand down).
  Future<void> pause() async {
    _playbackRequested = false;
    watchdogs.cancelAll();
    _cancelBackoff();
    await _handle?.pause();
    _setState(LivePlaybackState.paused);
  }

  /// Resumes playback.
  Future<void> resume() async {
    _playbackRequested = true;
    await _handle?.play();
    _setState(LivePlaybackState.playing);
  }

  /// Toggles pause/resume.
  Future<void> togglePlayPause() async {
    if (state == LivePlaybackState.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Sets volume (0.0–1.0).
  Future<void> setVolume(double volume) async {
    await _handle?.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Marks whether the current route owns the mounted video
  /// presentation.
  void setPresentationVisible(bool visible) {
    watchdogs.setPresentationVisible(visible);
  }

  /// Stops playback and releases the player.
  Future<void> close() async {
    _playbackRequested = false;
    _generation++;
    watchdogs.cancelAll();
    _cancelBackoff();
    await _eventSub?.cancel();
    _eventSub = null;
    final handle = _handle;
    _handle = null;
    _currentUrl = null;
    if (handle != null) {
      await kernel.release(handle.id);
    }
    _setState(LivePlaybackState.idle);
  }

  /// Disposes the controller.
  Future<void> dispose() async {
    await close();
    watchdogs.dispose();
    await _stateController.close();
    await _errorController.close();
  }

  // ---------------------------------------------------------------------------
  // Opening
  // ---------------------------------------------------------------------------

  Future<void> _open(int generation, String url) async {
    if (!_isCurrent(generation)) return;
    final request = _request;
    if (request == null) return;

    _currentUrl = url;
    _setState(LivePlaybackState.preparing);
    watchdogs.cancelAll();

    try {
      var handle = _handle;

      // Reuse the existing player when it is on the preferred
      // backend; the kernel's selector otherwise recreates it.
      if (handle == null || handle.disposed) {
        handle = await kernel.create();
        _bindHandle(handle);
      }

      if (!_isCurrent(generation)) return;

      await handle.open(_toSource(url, request));
      watchdogs.armSourceReady();
      _setState(LivePlaybackState.buffering);
    } catch (error) {
      if (!_isCurrent(generation)) return;
      await _recover(LivePlaybackError(
        message: 'open failed: $error',
        level: LiveRecoveryLevel.sameSource,
        cause: error,
      ), generation);
    }
  }

  PlayerSource _toSource(String url, LiveSourceRequest request) {
    final headers = request.headers;
    return PlayerSource(
      id: SourceId('live_${_generation}_$lineIndex'),
      uri: Uri.parse(url),
      headers: headers.isEmpty ? null : SourceHeaders(headers),
      title: request.title,
    );
  }

  // ---------------------------------------------------------------------------
  // Handle binding
  // ---------------------------------------------------------------------------

  void _bindHandle(PlayerHandle handle) {
    _handle = handle;
    _eventSub?.cancel();
    _eventSub = handle.adapter.events.listen(_onAdapterEvent, onError: (Object error) {
      _onAdapterEventError(error);
    });
  }

  void _onAdapterEvent(PlayerAdapterEvent adapterEvent) {
    final generation = _generation;
    // Playing / buffering feed the watchdogs.
    switch (adapterEvent) {
      case PlayerAdapterPlaying():
        _setState(LivePlaybackState.playing);
        watchdogs.onPlayingChanged(true, fromUserIntent: false);
        _sameEngineAttempts = 0;
        _backoffAttempt = 0;
        _cancelBackoff();
        _lineFallback.complete();
      case PlayerAdapterPaused():
        watchdogs.onPlayingChanged(false, fromUserIntent: !_playbackRequested);
        if (!_playbackRequested) {
          _setState(LivePlaybackState.paused);
        }
      case PlayerAdapterBuffering(buffering: final buffering):
        _setState(buffering ? LivePlaybackState.buffering : LivePlaybackState.playing);
        watchdogs.onBufferingChanged(buffering);
      case PlayerAdapterVideoSizeChanged():
        watchdogs.onFrameProgress();
      case PlayerAdapterErrorEvent(message: final message):
        _scheduleRecovery(
          LivePlaybackError(message: message, level: LiveRecoveryLevel.sameSource),
          generation,
        );
      default:
        break;
    }
  }

  void _onAdapterEventError(Object error) {
    _scheduleRecovery(
      LivePlaybackError(message: error.toString(), level: LiveRecoveryLevel.sameSource, cause: error),
      _generation,
    );
  }

  // ---------------------------------------------------------------------------
  // Recovery ladder
  // ---------------------------------------------------------------------------

  void _scheduleRecovery(LivePlaybackError error, int generation) {
    Timer.run(() => _recover(error, generation));
  }

  Future<void> _recover(LivePlaybackError error, int generation) async {
    if (!_isCurrent(generation) || !_playbackRequested) return;

    watchdogs.cancelAll();
    _setState(LivePlaybackState.buffering);

    // 1. Same-engine bounded replay for inferred stalls.
    if (error.cause is LiveStallKind &&
        _sameEngineAttempts < maxSameEngineRecoveryAttempts &&
        _currentUrl != null) {
      _sameEngineAttempts++;
      await _open(generation, _currentUrl!);
      return;
    }

    // 2. Line switch.
    final urls = lines;
    if (urls.length > 1 && _currentUrl != null) {
      final nextIndex = (lineIndex + 1) % urls.length;
      if (urls[nextIndex] != _currentUrl) {
        await _open(generation, urls[nextIndex]);
        return;
      }
    }

    // 3. Engine switch through the kernel's fallback registry.
    final candidates = kernel.registry.registrations
        .where((registration) => registration.enabled && registration.id != backendId)
        .map((registration) => registration.id)
        .toList();
    if (candidates.isNotEmpty) {
      _engineFallback.start(candidates, currentBackend: backendId);
      final next = _engineFallback.next();
      if (next != null) {
        final handle = _handle;
        if (handle != null) {
          try {
            final registration = kernel.registry.get(next);
            if (registration != null) {
              await handle.attachAdapter(registration);
              final url = _currentUrl;
              final request = _request;
              if (url != null && request != null) {
                await handle.open(_toSource(url, request));
                watchdogs.armSourceReady();
                return;
              }
            }
          } catch (_) {
            _engineFallback.markFailed();
          }
        }
      }
    }

    // 4. Backoff retry.
    if (_backoffAttempt < backoffDelays.length) {
      final delay = backoffDelays[_backoffAttempt++];
      _setState(LivePlaybackState.buffering);
      _cancelBackoff();
      _backoffTimer = Timer(delay, () {
        _backoffTimer = null;
        if (!_isCurrent(generation) || !_playbackRequested) return;
        _sameEngineAttempts = 0;
        _backoffAttempt = 0;
        final url = _currentUrl;
        if (url != null) {
          unawaited(_open(generation, url));
        }
      });
      return;
    }

    // 5. Terminal.
    _playbackRequested = false;
    _setState(LivePlaybackState.error);
    if (!_errorController.isClosed) {
      _errorController.add(LivePlaybackError(
        message: error.message,
        level: LiveRecoveryLevel.terminal,
        cause: error.cause,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  bool _isCurrent(int generation) => generation == _generation && _request != null;

  void _setState(LivePlaybackState next) {
    if (state == next) return;
    state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void _cancelBackoff() {
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Watchdog wiring (called from LiveWatchdogs callbacks)
  // ---------------------------------------------------------------------------

  void _wireWatchdogs() {
    watchdogs.onStall = (kind) {
      if (!_playbackRequested) return;
      _scheduleRecovery(
        LivePlaybackError(
          message: 'live stall: ${kind.name}',
          level: LiveRecoveryLevel.sameSource,
          cause: kind,
        ),
        _generation,
      );
    };
    watchdogs.onReassertPlay = () async {
      final handle = _handle;
      if (handle == null) return false;
      try {
        await handle.play();
        return true;
      } catch (_) {
        return false;
      }
    };
  }
}
