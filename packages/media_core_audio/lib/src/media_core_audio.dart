import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart' as asvc;
import 'package:audio_service_mpris/audio_service_mpris.dart' as ampris;
import 'package:audio_service_win/audio_service_win.dart' as aswin;
import 'package:audio_session/audio_session.dart' as asession;
import 'package:media_core/media_core.dart';

import 'audio_capability_config.dart';
import 'media_core_audio_handler.dart';

/// Audio capability driver for the media_core kernel.
///
/// [MediaCoreAudio] implements [KernelAudioDriver] and wires the
/// active player to the platform audio infrastructure:
///
/// ```text
/// PlayerHandle.playbackStream ──▶ MediaCoreAudioHandler ──▶ notification
/// notification buttons        ──▶ MediaCoreAudioHandler ──▶ PlayerHandle
/// audio focus interruptions   ──▶ pause / duck / resume
/// headphones unplugged        ──▶ pause
/// ```
///
/// Usage:
///
/// ```dart
/// final audio = MediaCoreAudio();
/// await audio.initialize();          // once, early (before runApp is fine)
/// kernel.attachAudio(audio);         // kernel notifies active players
///
/// // or drive it manually without a kernel:
/// audio.setActive(handle);
/// ```
final class MediaCoreAudio implements KernelAudioDriver {
  /// Creates the driver.
  MediaCoreAudio({
    this.config = const AudioCapabilityConfig(),
    asession.AudioSessionConfiguration? sessionConfiguration,
  }) : _sessionConfiguration = sessionConfiguration;

  /// Capability configuration.
  final AudioCapabilityConfig config;

  final asession.AudioSessionConfiguration? _sessionConfiguration;

  MediaCoreAudioHandler? _handler;
  PlayerHandle? _active;
  StreamSubscription<void>? _playbackSub;
  StreamSubscription<asession.AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;

  bool _initialized = false;
  bool _disposed = false;
  bool _ducked = false;
  bool _resumeOnInterruptionEnd = false;
  double _volumeBeforeDuck = 1.0;

  /// The underlying audio_service handler.
  ///
  /// Null before [initialize].
  MediaCoreAudioHandler? get handler => _handler;

  /// The active player, if any.
  PlayerHandle? get active => _active;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initializes audio_service and the audio session.
  ///
  /// Call once, early (before `runApp` is fine).
  ///
  /// Platform integration:
  ///
  /// - Android/iOS: media notification + lock screen controls
  /// - Windows: SMTC (System Media Transport Controls) via
  ///   audio_service_win
  /// - Linux: MPRIS (D-Bus) via audio_service_mpris — shows up in
  ///   GNOME/KDE media applets and media keys work
  ///
  /// On platforms without audio_session support the session part
  /// is skipped.
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }
    _initialized = true;

    _registerPlatformImplementation();

    _handler = await asvc.AudioService.init(
      builder: () => MediaCoreAudioHandler(
        onPlay: () async => _active?.play(),
        onPause: () async => _active?.pause(),
        onSeek: (position) async => _active?.seek(position),
        onStop: () async => _active?.stop(),
        controlsBuilder: _buildControls,
      ),
      config: asvc.AudioServiceConfig(
        androidNotificationChannelId: config.androidNotificationChannelId,
        androidNotificationChannelName: config.androidNotificationChannelName,
        androidNotificationOngoing: config.androidNotificationOngoing,
      ),
    );

    if (!_supportsAudioSession) {
      return;
    }

    try {
      final session = await asession.AudioSession.instance;
      await session.configure(_sessionConfiguration ?? const asession.AudioSessionConfiguration.music());

      if (config.processInterruptions) {
        _interruptionSub = session.interruptionEventStream.listen(_onInterruption, onError: (_) {});
      }
      if (config.pauseOnBecomingNoisy) {
        _noisySub = session.becomingNoisyEventStream.listen((_) => _active?.pause(), onError: (_) {});
      }
    } catch (_) {
      // Platform without a functional audio_session implementation.
      // Playback still works; focus handling is simply unavailable.
    }
  }

  /// Releases this driver.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    await _playbackSub?.cancel();
    _playbackSub = null;
    await _interruptionSub?.cancel();
    _interruptionSub = null;
    await _noisySub?.cancel();
    _noisySub = null;

    _handler?.publishIdle();
    _handler?.clearMediaItem();
    _active = null;
    _handler = null;
  }

  // ---------------------------------------------------------------------------
  // KernelAudioDriver
  // ---------------------------------------------------------------------------

  @override
  void onPlayerActivated(PlayerHandle handle) {
    setActive(handle);
  }

  @override
  void onPlayerDeactivated() {
    setActive(null);
  }

  // ---------------------------------------------------------------------------
  // Active player binding
  // ---------------------------------------------------------------------------

  /// Binds [handle] as the audio-active player.
  ///
  /// Pass null to detach. The kernel calls this automatically via
  /// `attachAudio`; apps without a kernel can drive it directly.
  void setActive(PlayerHandle? handle) {
    if (_disposed || identical(handle, _active)) {
      return;
    }

    _playbackSub?.cancel();
    _playbackSub = null;
    _active = handle;
    _ducked = false;
    _resumeOnInterruptionEnd = false;

    final handler = _handler;
    if (handler == null) {
      return;
    }

    if (handle == null) {
      handler.publishIdle();
      handler.clearMediaItem();
      return;
    }

    handler.publishMediaItem(_mediaItemFor(handle));
    _publishCurrent(handle);

    _playbackSub = handle.playbackStream.listen(
      (_) => _publishCurrent(handle),
      onError: (_) {},
      onDone: () {
        if (identical(_active, handle)) {
          setActive(null);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Interruptions
  // ---------------------------------------------------------------------------

  void _onInterruption(asession.AudioInterruptionEvent event) {
    final active = _active;
    if (active == null) {
      return;
    }

    if (event.begin) {
      switch (event.type) {
        case asession.AudioInterruptionType.duck:
          if (!_ducked) {
            _ducked = true;
            _volumeBeforeDuck = active.playback.volume;
            active.setVolume(_volumeBeforeDuck * config.duckFactor);
          }
        case asession.AudioInterruptionType.pause:
        case asession.AudioInterruptionType.unknown:
          _resumeOnInterruptionEnd = config.resumeAfterInterruption && active.playback.isPlaying;
          active.pause();
      }
    } else {
      if (_ducked) {
        _ducked = false;
        active.setVolume(_volumeBeforeDuck);
      }
      if (_resumeOnInterruptionEnd) {
        _resumeOnInterruptionEnd = false;
        active.play();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _supportsAudioSession {
    // audio_session has no implementation on Windows/Linux.
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  void _registerPlatformImplementation() {
    // Federated plugins normally self-register through the
    // generated plugin registrant. Explicit registration covers
    // custom embedders and makes the backend selection visible.
    try {
      if (Platform.isWindows) {
        aswin.AudioServiceWin.registerWith();
      } else if (Platform.isLinux) {
        ampris.AudioServiceMpris.registerWith();
      }
    } catch (_) {
      // Registration is best-effort: audio_service falls back to
      // its default platform implementation when this fails.
    }
  }

  List<asvc.MediaControl> _buildControls(bool playing) {
    if (!config.showControls) {
      return const <asvc.MediaControl>[];
    }
    return <asvc.MediaControl>[
      asvc.MediaControl(
        androidIcon: playing ? config.pauseIcon : config.playIcon,
        label: playing ? 'Pause' : 'Play',
        action: playing ? asvc.MediaAction.pause : asvc.MediaAction.play,
      ),
      asvc.MediaControl(androidIcon: config.stopIcon, label: 'Stop', action: asvc.MediaAction.stop),
    ];
  }

  void _publishCurrent(PlayerHandle handle) {
    final playback = handle.playback;
    _handler?.publishState(
      AudioHandlerState(
        playing: playback.isPlaying,
        position: playback.position,
        duration: playback.duration,
        speed: playback.rate,
      ),
      controls: _buildControls(playback.isPlaying),
    );
  }

  AudioHandlerMediaItem _mediaItemFor(PlayerHandle handle) {
    final source = handle.source;
    final uri = source?.uri;
    final title =
        source?.hasTitle == true
        ? source!.title!
        : (uri == null ? 'Media' : (uri.pathSegments.isEmpty ? uri.toString() : uri.pathSegments.last));

    final artUri = source?.metadataValue('artUri');
    final duration = handle.playback.duration;

    return AudioHandlerMediaItem(
      id: source?.id.value ?? handle.id.value,
      title: title,
      duration: duration == Duration.zero ? null : duration,
      artUri: artUri is String ? Uri.tryParse(artUri) : null,
    );
  }
}
