import 'dart:async';

import 'package:flutter/foundation.dart' show protected;

import '../core/player_error.dart';
import '../core/player_state.dart';
import '../error/player_error_code.dart';
import '../source/player_source.dart';
import 'player_adapter.dart';
import 'player_adapter_capabilities.dart';
import 'player_adapter_context.dart';
import 'player_adapter_event.dart';
import 'player_adapter_exception.dart';
import 'player_adapter_metrics.dart';

/// Template-method base for [PlayerAdapter] implementations.
///
/// [PlayerAdapterBase] owns the scaffolding every backend needs —
/// the event stream, the state machine, lifecycle guards,
/// source-scoped event acceptance and error normalization through
/// [PlayerError] — so a concrete adapter only overrides the engine
/// hooks:
///
/// - [onInitialize] creates the engine and binds its listeners
/// - [onBeforeOpen] / [onOpen] / [onAfterOpen] hand a source over
/// - [onPlay], [onPause], [onStop], [onSeek], [onSetVolume] and
///   [onSetRate] execute the playback commands
/// - [onClose] / [onDispose] release the engine
///
/// Engine callbacks report what happened through the `emit*`
/// helpers. Reports are dropped while the source gate is closed
/// (see [gatesSourceEvents]), and a failure arriving during the
/// open window is deferred until [open] settles, where it either
/// fails the open through [PlayerAdapterOpenException] or is
/// dropped when the engine reports the source as healthy.
///
/// Responsibilities:
///
/// - run the adapter lifecycle templates
/// - publish normalized adapter events
/// - normalize engine failures into [PlayerError]
///
/// It does not:
///
/// - create engine instances (that is [onInitialize])
/// - interpret engine payloads (that is the `emit*` callers)
/// - select backends or retry opens
///
/// Those belong to:
///
/// - PlayerAdapterFactory
/// - LivePlaybackController / FallbackManager
abstract base class PlayerAdapterBase implements PlayerAdapter {
  /// Creates the adapter.
  PlayerAdapterBase({String? id, PlayerAdapterCapabilities? capabilities})
      : _id = id ?? 'adapter',
        _capabilities = capabilities ?? const PlayerAdapterCapabilities();

  final String _id;
  final PlayerAdapterCapabilities _capabilities;

  PlayerState _state = PlayerState.idle;
  PlayerAdapterMetrics _metrics = const PlayerAdapterMetrics();

  bool _initialized = false;
  bool _disposed = false;

  // Source-scoped event acceptance with deferred open errors.
  bool _acceptSourceEvents = false;
  bool _sourceOpening = false;
  PlayerError? _deferredEngineError;

  // Last video geometry published for the current source; the
  // deduplicating size helper compares against it.
  int? _lastReportedWidth;
  int? _lastReportedHeight;

  final StreamController<PlayerAdapterEvent> _eventController =
      StreamController<PlayerAdapterEvent>.broadcast();

  @override
  String get id => _id;

  @override
  PlayerAdapterCapabilities get capabilities => _capabilities;

  @override
  PlayerState get state => _state;

  @override
  PlayerAdapterMetrics get metrics => _metrics;

  @override
  Stream<PlayerAdapterEvent> get events => _eventController.stream;

  @override
  bool get initialized => _initialized;

  /// Whether the adapter has been disposed.
  @protected
  bool get isDisposed => _disposed;

  /// Whether engine-reported events are scoped to the source
  /// currently being opened.
  ///
  /// When true (the default), engine reports published before the
  /// first [open] and after [stop] / [close] are dropped, so a
  /// previous source's late events never leak into the next
  /// generation. Engines whose event subscriptions are bound once
  /// for the whole adapter lifetime and rely on the engine itself to
  /// detach stale payloads can turn the gate off.
  @protected
  bool get gatesSourceEvents => true;

  /// Whether engine-originated reports may currently be published.
  @protected
  bool get acceptsEngineEvents => !_disposed && (!gatesSourceEvents || _acceptSourceEvents);

  /// Whether the engine still reports a failure for the source that
  /// [onOpen] just handed over.
  ///
  /// Only consulted when a deferred engine error arrived during the
  /// open window; a source the engine considers healthy accepts the
  /// open even if a stale error was seen while it was setting up.
  @protected
  bool get engineReportsOpenFailure => false;

  // ---------------------------------------------------------------------------
  // Lifecycle templates
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize(PlayerAdapterContext context) async {
    if (_initialized) return;

    await onInitialize(context);
    _state = _state.initializingState().readyState();
    _initialized = true;
  }

  @override
  Future<void> open(PlayerSource source) async {
    requireReady();

    // Source-scoped reset: the previous source's late events must
    // not leak into this generation.
    _acceptSourceEvents = false;
    _deferredEngineError = null;
    _lastReportedWidth = null;
    _lastReportedHeight = null;

    try {
      await onBeforeOpen(source);

      // The engine can emit an exception while the source setup is
      // still pending. Bind that error to this source instead of
      // dropping the only event before the gate opens.
      _sourceOpening = true;
      _acceptSourceEvents = true;
      try {
        await onOpen(source);
      } finally {
        _sourceOpening = false;
      }

      final deferred = _deferredEngineError;
      _deferredEngineError = null;
      if (deferred != null && engineReportsOpenFailure) {
        _acceptSourceEvents = false;
        _fail(deferred);
        throw PlayerAdapterOpenException(deferred);
      }

      _state = _state.openingState().withSource(true).readyState();
      _addEvent(PlayerAdapterEvent.opened(source: source.id.value));

      await onAfterOpen(source);
    } catch (error, stackTrace) {
      _sourceOpening = false;
      _acceptSourceEvents = false;
      if (error is! PlayerAdapterOpenException) {
        _fail(PlayerError(
          code: PlayerErrorCode.backendOpenFailed,
          message: '$id open failed: $error',
          cause: error,
          stackTrace: stackTrace,
        ));
      }
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    requireReady();
    await onPlay();
  }

  @override
  Future<void> pause() async {
    requireReady();
    await onPause();
  }

  @override
  Future<void> stop() async {
    requireReady();
    _acceptSourceEvents = false;
    await onStop();
    _state = _state.stoppedState().withSource(false);
    _addEvent(const PlayerAdapterEvent.stopped());
  }

  @override
  Future<void> seek(Duration position) async {
    requireReady();
    await onSeek(position);
    _addEvent(PlayerAdapterEvent.positionChanged(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    requireReady();
    await onSetVolume(volume);
  }

  @override
  Future<void> setRate(double rate) async {
    requireReady();
    await onSetRate(rate);
    _addEvent(PlayerAdapterEvent.rateChanged(rate: rate));
  }

  @override
  Future<void> close() async {
    if (!_initialized || _disposed) return;
    _acceptSourceEvents = false;
    await onClose();
    _state = _state.stoppedState().withSource(false);
    _addEvent(const PlayerAdapterEvent.stopped());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _state = _state.disposingState();
    await onDispose();
    _state = _state.disposedState();

    if (!_eventController.isClosed) {
      await _eventController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Engine contract
  // ---------------------------------------------------------------------------

  /// Creates the engine and binds its listeners.
  @protected
  Future<void> onInitialize(PlayerAdapterContext context);

  /// Prepares engine options for the source about to open.
  ///
  /// Runs before the open window begins, so engine events fired here
  /// are still gated out.
  @protected
  Future<void> onBeforeOpen(PlayerSource source) async {}

  /// Hands the source to the engine.
  ///
  /// Runs inside the open window: engine reports arriving while this
  /// hook is pending defer their failures to the open outcome.
  @protected
  Future<void> onOpen(PlayerSource source);

  /// Adjusts playback after the source opened.
  @protected
  Future<void> onAfterOpen(PlayerSource source) async {}

  @protected
  Future<void> onPlay();

  @protected
  Future<void> onPause();

  @protected
  Future<void> onStop();

  @protected
  Future<void> onSeek(Duration position);

  @protected
  Future<void> onSetVolume(double volume);

  @protected
  Future<void> onSetRate(double rate);

  @protected
  Future<void> onClose();

  @protected
  Future<void> onDispose();

  /// Throws when commands cannot be accepted.
  @protected
  void requireReady() {
    if (!_initialized || _disposed) {
      throw StateError('$runtimeType is not initialized or has been disposed.');
    }
  }

  // ---------------------------------------------------------------------------
  // Engine reports
  // ---------------------------------------------------------------------------

  /// Reports that playback started.
  @protected
  void emitPlaying() {
    if (!acceptsEngineEvents) return;
    _state = _state.playingState();
    _addEvent(const PlayerAdapterEvent.playing());
  }

  /// Reports that playback paused.
  @protected
  void emitPaused() {
    if (!acceptsEngineEvents) return;
    _state = _state.pausedState();
    _addEvent(const PlayerAdapterEvent.paused());
  }

  /// Reports that playback completed.
  @protected
  void emitCompleted() {
    if (!acceptsEngineEvents) return;
    _state = _state.completedState();
    _addEvent(const PlayerAdapterEvent.completed());
  }

  /// Reports a buffering transition.
  ///
  /// While buffering starts the adapter enters the buffering state.
  /// When it ends, [resumePlaying] decides whether playback is
  /// reported as playing or paused; engines whose own state machine
  /// re-asserts the playback state separately leave it null.
  @protected
  void emitBuffering(bool buffering, {bool? resumePlaying, double? progress}) {
    if (!acceptsEngineEvents) return;
    if (buffering) {
      _state = _state.bufferingState();
    } else if (resumePlaying != null) {
      _state = resumePlaying ? _state.playingState() : _state.pausedState();
    }
    _addEvent(PlayerAdapterEvent.buffering(buffering: buffering, progress: progress));
  }

  /// Reports decoded video dimensions.
  @protected
  void emitVideoSizeChanged(int width, int height) {
    if (!acceptsEngineEvents) return;
    if (width <= 0 || height <= 0) return;
    _state = _state.withVideoEnabled(true);
    _addEvent(PlayerAdapterEvent.videoSizeChanged(width: width, height: height));
  }

  /// Reports decoded video dimensions, dropping repeats.
  ///
  /// The comparison resets on every [open], so the first geometry of
  /// each source is always published.
  @protected
  void emitVideoSizeChangedIfChanged(int width, int height) {
    if (!acceptsEngineEvents) return;
    if (width <= 0 || height <= 0) return;
    if (width == _lastReportedWidth && height == _lastReportedHeight) return;
    _lastReportedWidth = width;
    _lastReportedHeight = height;
    emitVideoSizeChanged(width, height);
  }

  /// Reports the playback position.
  @protected
  void emitPositionChanged(Duration position) {
    if (!acceptsEngineEvents) return;
    _addEvent(PlayerAdapterEvent.positionChanged(position: position));
  }

  /// Reports the media duration.
  @protected
  void emitDurationChanged(Duration duration) {
    if (!acceptsEngineEvents) return;
    _addEvent(PlayerAdapterEvent.durationChanged(duration: duration));
  }

  /// Reports the output volume.
  @protected
  void emitVolumeChanged(double volume) {
    if (!acceptsEngineEvents) return;
    _addEvent(PlayerAdapterEvent.volumeChanged(volume: volume));
  }

  /// Reports an engine failure through the unified error model.
  ///
  /// Reports arriving while the source gate is closed are dropped;
  /// failures during the open window are deferred and surface
  /// through [open]'s deferred-error check.
  @protected
  void reportEngineError({
    required String message,
    PlayerErrorCode code = PlayerErrorCode.playbackFailed,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    if (_disposed) return;
    if (gatesSourceEvents && !_acceptSourceEvents) return;

    final error = PlayerError(
      code: code,
      message: message,
      cause: cause,
      stackTrace: stackTrace,
    );
    if (_sourceOpening && gatesSourceEvents) {
      _deferredEngineError = error;
      return;
    }
    _fail(error);
  }

  /// Marks the adapter failed and publishes [error].
  @protected
  void fail(PlayerError error) => _fail(error);

  /// Replaces the metrics snapshot.
  @protected
  void updateMetrics(PlayerAdapterMetrics Function(PlayerAdapterMetrics metrics) transform) {
    _metrics = transform(_metrics);
  }

  /// Publishes an adapter event directly.
  ///
  /// Engine-originated payloads should go through the `emit*`
  /// helpers, which own the state transitions and the source gate.
  @protected
  void emitEvent(PlayerAdapterEvent event) => _addEvent(event);

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _addEvent(PlayerAdapterEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _fail(PlayerError error) {
    _state = _state.errorState();
    _addEvent(PlayerAdapterEvent.error(message: error.message, error: error, stackTrace: error.stackTrace));
  }
}
