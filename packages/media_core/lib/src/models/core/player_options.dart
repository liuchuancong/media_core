import 'package:built_value/built_value.dart';
import 'package:media_core/src/core/config/player_constants.dart';
import 'package:media_core/src/identity/source_id.dart';

part 'player_options.g.dart';

/// Defines immutable runtime options used to configure a player.
///
/// [PlayerOptions] describes how a player should operate.
///
/// It contains playback preferences, media output preferences, and feature
/// switches. Player capabilities describe what the player implementation is
/// capable of doing.
///
/// Recovery, fallback, metrics, and diagnostics options are retained here for
/// compatibility with the current core API. Their execution and runtime state
/// belong to their respective modules.
abstract class PlayerOptions implements Built<PlayerOptions, PlayerOptionsBuilder> {
  /// Builds PlayerOptions from a [updates] callback — the codegen entry.
  factory PlayerOptions([void Function(PlayerOptionsBuilder)? updates]) = _$PlayerOptions;

  /// Creates immutable player options, replacing only the options named.
  ///
  /// An option left out keeps the default written in [_initialize], which is
  /// the default the original constructor spelled out.
  factory PlayerOptions.of({
    bool? autoPlay,
    bool? autoInitialize,
    bool? loop,
    bool? muted,
    double? volume,
    double? playbackRate,
    bool? preload,
    bool? keepAlive,
    bool? preferHardwareDecoding,
    bool? enableAudio,
    bool? enableVideo,
    bool? enableSubtitles,
    bool? enableBuffering,
    bool? enableRecovery,
    bool? enableFallback,
    bool? enableMetrics,
    bool? enableDiagnostics,
    SourceId? sourceId,
    int? maxRecoveryAttempts,
    int? maxFallbackAttempts,
  }) {
    return PlayerOptions((builder) {
      if (autoPlay != null) {
        builder.autoPlay = autoPlay;
      }
      if (autoInitialize != null) {
        builder.autoInitialize = autoInitialize;
      }
      if (loop != null) {
        builder.loop = loop;
      }
      if (muted != null) {
        builder.muted = muted;
      }
      if (volume != null) {
        builder.volume = volume;
      }
      if (playbackRate != null) {
        builder.playbackRate = playbackRate;
      }
      if (preload != null) {
        builder.preload = preload;
      }
      if (keepAlive != null) {
        builder.keepAlive = keepAlive;
      }
      if (preferHardwareDecoding != null) {
        builder.preferHardwareDecoding = preferHardwareDecoding;
      }
      if (enableAudio != null) {
        builder.enableAudio = enableAudio;
      }
      if (enableVideo != null) {
        builder.enableVideo = enableVideo;
      }
      if (enableSubtitles != null) {
        builder.enableSubtitles = enableSubtitles;
      }
      if (enableBuffering != null) {
        builder.enableBuffering = enableBuffering;
      }
      if (enableRecovery != null) {
        builder.enableRecovery = enableRecovery;
      }
      if (enableFallback != null) {
        builder.enableFallback = enableFallback;
      }
      if (enableMetrics != null) {
        builder.enableMetrics = enableMetrics;
      }
      if (enableDiagnostics != null) {
        builder.enableDiagnostics = enableDiagnostics;
      }
      if (sourceId != null) {
        builder.sourceId = sourceId;
      }
      if (maxRecoveryAttempts != null) {
        builder.maxRecoveryAttempts = maxRecoveryAttempts;
      }
      if (maxFallbackAttempts != null) {
        builder.maxFallbackAttempts = maxFallbackAttempts;
      }
    });
  }

  PlayerOptions._();

  /// A player nobody configured still has to answer for output, recovery and
  /// fallback, so an unset option is not a disabled one: the switches default
  /// to the behaviour a viewer expects from a media player.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerOptionsBuilder builder) => builder
    ..autoPlay = false
    ..autoInitialize = true
    ..loop = false
    ..muted = false
    ..volume = PlayerConstants.defaultVolume
    ..playbackRate = PlayerConstants.defaultPlaybackRate
    ..preload = true
    ..keepAlive = true
    ..preferHardwareDecoding = true
    ..enableAudio = true
    ..enableVideo = true
    ..enableSubtitles = true
    ..enableBuffering = true
    ..enableRecovery = true
    ..enableFallback = true
    ..enableMetrics = true
    ..enableDiagnostics = false
    ..maxRecoveryAttempts = PlayerConstants.maxRecoveryAttempts
    ..maxFallbackAttempts = PlayerConstants.maxFallbackAttempts;

  /// A volume or rate outside the range the backend accepts would be clamped
  /// silently somewhere far from this value; the range is checked where it is
  /// authored, on every path that builds options.
  @BuiltValueHook(finalizeBuilder: true)
  static void _validate(PlayerOptionsBuilder builder) {
    final volume = builder.volume;
    final playbackRate = builder.playbackRate;
    final maxRecoveryAttempts = builder.maxRecoveryAttempts;
    final maxFallbackAttempts = builder.maxFallbackAttempts;
    assert(
      volume == null || (volume >= PlayerConstants.minVolume && volume <= PlayerConstants.maxVolume),
      'Volume must be between 0.0 and 1.0.',
    );
    assert(
      playbackRate == null ||
          (playbackRate >= PlayerConstants.minPlaybackRate && playbackRate <= PlayerConstants.maxPlaybackRate),
      'Playback rate is outside the supported range.',
    );
    assert(maxRecoveryAttempts == null || maxRecoveryAttempts >= 0, 'Max recovery attempts must not be negative.');
    assert(maxFallbackAttempts == null || maxFallbackAttempts >= 0, 'Max fallback attempts must not be negative.');
  }

  /// Whether playback should start automatically after opening.
  bool get autoPlay;

  /// Whether the player should initialize automatically.
  bool get autoInitialize;

  /// Whether playback should restart automatically after completion.
  bool get loop;

  /// Whether audio output should initially be muted.
  bool get muted;

  /// Initial player volume in the range from 0.0 to 1.0.
  double get volume;

  /// Initial playback rate.
  double get playbackRate;

  /// Whether the player should preload media data.
  bool get preload;

  /// Whether the player should keep its resources alive when temporarily
  /// detached from presentation.
  bool get keepAlive;

  /// Whether hardware decoding should be preferred when available.
  bool get preferHardwareDecoding;

  /// Whether audio output is enabled.
  bool get enableAudio;

  /// Whether video output is enabled.
  bool get enableVideo;

  /// Whether subtitle processing and presentation are enabled.
  bool get enableSubtitles;

  /// Whether buffering is enabled.
  bool get enableBuffering;

  /// Whether automatic recovery is enabled.
  bool get enableRecovery;

  /// Whether fallback handling is enabled.
  bool get enableFallback;

  /// Whether runtime metrics collection is enabled.
  bool get enableMetrics;

  /// Whether verbose diagnostics are enabled.
  bool get enableDiagnostics;

  /// Optional source identifier associated with these options.
  SourceId? get sourceId;

  /// Maximum number of recovery attempts allowed for an operation.
  int get maxRecoveryAttempts;

  /// Maximum number of fallback attempts allowed for an operation.
  int get maxFallbackAttempts;

  /// Default player options.
  static final PlayerOptions defaults = PlayerOptions.of();

  /// Minimal player options.
  static final PlayerOptions minimal = PlayerOptions.of(
    preload: false,
    keepAlive: false,
    enableSubtitles: false,
    enableRecovery: false,
    enableFallback: false,
    enableMetrics: false,
    maxRecoveryAttempts: 0,
    maxFallbackAttempts: 0,
  );

  /// Options optimized for audio-only playback.
  static final PlayerOptions audioOnly = PlayerOptions.of(enableVideo: false, enableSubtitles: false);

  /// Options optimized for video-only playback.
  static final PlayerOptions videoOnly = PlayerOptions.of(enableAudio: false);

  /// Options optimized for combined audio-video playback.
  static final PlayerOptions audioVideo = PlayerOptions.of();

  /// Whether a source identifier has been configured.
  bool get hasSource => sourceId != null;

  /// Whether audio output is enabled.
  bool get hasAudioOutput => enableAudio;

  /// Whether video output is enabled.
  bool get hasVideoOutput => enableVideo;

  /// Whether the options allow automatic recovery.
  ///
  /// This only describes configuration. Recovery execution belongs to the
  /// recovery module.
  bool get canRecover {
    return enableRecovery && maxRecoveryAttempts > 0;
  }

  /// Whether the options allow fallback.
  ///
  /// This only describes configuration. Fallback execution belongs to the
  /// fallback module.
  bool get canFallback {
    return enableFallback && maxFallbackAttempts > 0;
  }

  /// Whether diagnostics are enabled.
  bool get hasDiagnostics => enableDiagnostics;

  /// Whether the playback rate is normal.
  bool get isNormalPlaybackRate {
    return playbackRate == PlayerConstants.defaultPlaybackRate;
  }

  /// Whether playback is faster than normal.
  bool get isFastPlayback {
    return playbackRate > PlayerConstants.defaultPlaybackRate;
  }

  /// Whether playback is slower than normal.
  bool get isSlowPlayback {
    return playbackRate < PlayerConstants.defaultPlaybackRate;
  }

  /// Whether the configured volume is muted.
  bool get isMuted => muted;

  /// Whether this represents the minimal preset.
  bool get isMinimal {
    return this == PlayerOptions.minimal;
  }

  /// Returns options without a source identifier.
  PlayerOptions withoutSource() {
    return rebuild((builder) => builder..sourceId = null);
  }

  /// Whether two option sets configure the same media outputs.
  bool isSameMedia(PlayerOptions other) {
    return enableAudio == other.enableAudio &&
        enableVideo == other.enableVideo &&
        enableSubtitles == other.enableSubtitles;
  }

  /// Whether two option sets reference the same source.
  bool isSameSource(PlayerOptions other) {
    return sourceId == other.sourceId;
  }
}
