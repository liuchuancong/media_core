import 'package:built_value/built_value.dart';

part 'player_capabilities.g.dart';

/// Describes the operations supported by a player implementation.
///
/// [PlayerCapabilities] represents what a player implementation can do,
/// rather than the capabilities of the currently loaded media.
///
/// This is a static capability description and must not contain runtime
/// playback state.
abstract class PlayerCapabilities implements Built<PlayerCapabilities, PlayerCapabilitiesBuilder> {
  /// Builds PlayerCapabilities from a [updates] callback — the codegen entry.
  factory PlayerCapabilities([void Function(PlayerCapabilitiesBuilder)? updates]) = _$PlayerCapabilities;

  /// Creates a capability set, replacing only the operations named.
  ///
  /// A omitted flag keeps the default written in [_initialize], which is the
  /// same default the original constructor spelled out.
  factory PlayerCapabilities.of({
    bool? play,
    bool? pause,
    bool? stop,
    bool? seek,
    bool? setVolume,
    bool? setPlaybackSpeed,
    bool? setLooping,
    bool? setMuted,
    bool? fullscreen,
    bool? pictureInPicture,
    bool? backgroundPlayback,
    bool? frameStep,
    bool? snapshot,
  }) {
    return PlayerCapabilities((builder) {
      if (play != null) {
        builder.play = play;
      }
      if (pause != null) {
        builder.pause = pause;
      }
      if (stop != null) {
        builder.stop = stop;
      }
      if (seek != null) {
        builder.seek = seek;
      }
      if (setVolume != null) {
        builder.setVolume = setVolume;
      }
      if (setPlaybackSpeed != null) {
        builder.setPlaybackSpeed = setPlaybackSpeed;
      }
      if (setLooping != null) {
        builder.setLooping = setLooping;
      }
      if (setMuted != null) {
        builder.setMuted = setMuted;
      }
      if (fullscreen != null) {
        builder.fullscreen = fullscreen;
      }
      if (pictureInPicture != null) {
        builder.pictureInPicture = pictureInPicture;
      }
      if (backgroundPlayback != null) {
        builder.backgroundPlayback = backgroundPlayback;
      }
      if (frameStep != null) {
        builder.frameStep = frameStep;
      }
      if (snapshot != null) {
        builder.snapshot = snapshot;
      }
    });
  }

  PlayerCapabilities._();

  /// Every player is expected to support the core playback controls, so an
  /// unset capability set is not an empty one; the extensions are what a
  /// caller has to opt into.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerCapabilitiesBuilder builder) => builder
    ..play = true
    ..pause = true
    ..stop = true
    ..seek = true
    ..setVolume = true
    ..setPlaybackSpeed = true
    ..setLooping = true
    ..setMuted = true
    ..fullscreen = false
    ..pictureInPicture = false
    ..backgroundPlayback = false
    ..frameStep = false
    ..snapshot = false;

  /// Whether the player can start or resume playback.
  bool get play;

  /// Whether the player can pause playback.
  bool get pause;

  /// Whether the player can stop playback.
  bool get stop;

  /// Whether the player supports seeking.
  bool get seek;

  /// Whether the player can change volume.
  bool get setVolume;

  /// Whether the player can change playback speed.
  bool get setPlaybackSpeed;

  /// Whether the player can enable or disable looping.
  bool get setLooping;

  /// Whether the player can mute or unmute audio.
  bool get setMuted;

  /// Whether the player supports fullscreen presentation.
  bool get fullscreen;

  /// Whether the player supports picture-in-picture presentation.
  bool get pictureInPicture;

  /// Whether the player can continue playback while the application is
  /// backgrounded.
  bool get backgroundPlayback;

  /// Whether the player supports stepping between video frames.
  bool get frameStep;

  /// Whether the player can capture a video frame.
  bool get snapshot;

  /// A capability set with no supported operations.
  static final PlayerCapabilities none = PlayerCapabilities.of(
    play: false,
    pause: false,
    stop: false,
    seek: false,
    setVolume: false,
    setPlaybackSpeed: false,
    setLooping: false,
    setMuted: false,
  );

  /// A capability set with all player operations enabled.
  static final PlayerCapabilities full = PlayerCapabilities.of(
    fullscreen: true,
    pictureInPicture: true,
    backgroundPlayback: true,
    frameStep: true,
    snapshot: true,
  );

  /// A minimal capability set for basic playback control.
  static final PlayerCapabilities basic = PlayerCapabilities.of();

  /// Creates a copy with the specified capabilities replaced.
  ///
  /// A null argument keeps the current value, exactly as the hand-written
  /// copy this replaced did.
  PlayerCapabilities copyWith({
    bool? play,
    bool? pause,
    bool? stop,
    bool? seek,
    bool? setVolume,
    bool? setPlaybackSpeed,
    bool? setLooping,
    bool? setMuted,
    bool? fullscreen,
    bool? pictureInPicture,
    bool? backgroundPlayback,
    bool? frameStep,
    bool? snapshot,
  }) {
    return rebuild((builder) {
      if (play != null) {
        builder.play = play;
      }
      if (pause != null) {
        builder.pause = pause;
      }
      if (stop != null) {
        builder.stop = stop;
      }
      if (seek != null) {
        builder.seek = seek;
      }
      if (setVolume != null) {
        builder.setVolume = setVolume;
      }
      if (setPlaybackSpeed != null) {
        builder.setPlaybackSpeed = setPlaybackSpeed;
      }
      if (setLooping != null) {
        builder.setLooping = setLooping;
      }
      if (setMuted != null) {
        builder.setMuted = setMuted;
      }
      if (fullscreen != null) {
        builder.fullscreen = fullscreen;
      }
      if (pictureInPicture != null) {
        builder.pictureInPicture = pictureInPicture;
      }
      if (backgroundPlayback != null) {
        builder.backgroundPlayback = backgroundPlayback;
      }
      if (frameStep != null) {
        builder.frameStep = frameStep;
      }
      if (snapshot != null) {
        builder.snapshot = snapshot;
      }
    });
  }

  /// Returns whether this capability set supports every operation required
  /// by [other].
  bool supports(PlayerCapabilities other) {
    return (!other.play || play) &&
        (!other.pause || pause) &&
        (!other.stop || stop) &&
        (!other.seek || seek) &&
        (!other.setVolume || setVolume) &&
        (!other.setPlaybackSpeed || setPlaybackSpeed) &&
        (!other.setLooping || setLooping) &&
        (!other.setMuted || setMuted) &&
        (!other.fullscreen || fullscreen) &&
        (!other.pictureInPicture || pictureInPicture) &&
        (!other.backgroundPlayback || backgroundPlayback) &&
        (!other.frameStep || frameStep) &&
        (!other.snapshot || snapshot);
  }
}
