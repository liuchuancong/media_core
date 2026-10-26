import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/audio/audio_session_status.dart' show AudioSessionStatus;

part 'audio_session_state.g.dart';

/// Immutable snapshot of the audio-session lifecycle.
///
/// This type describes only the lifecycle of the audio session. It does not
/// contain focus, volume, mute, or route information; those concerns are
/// represented by their respective audio abstractions.
abstract class AudioSessionState implements Built<AudioSessionState, AudioSessionStateBuilder> {
  /// Builds AudioSessionState from a [updates] callback — the codegen entry.
  factory AudioSessionState([void Function(AudioSessionStateBuilder)? updates]) = _$AudioSessionState;

  /// Creates an audio-session state.
  factory AudioSessionState.of({AudioSessionStatus status = AudioSessionStatus.inactive, int generation = 0}) {
    return AudioSessionState((builder) => builder..status = status..generation = generation);
  }

  /// Creates the initial inactive state.
  factory AudioSessionState.inactive({int generation = 0}) {
    return AudioSessionState.of(generation: generation);
  }

  /// Creates an activating state.
  factory AudioSessionState.activating({int generation = 0}) {
    return AudioSessionState.of(status: AudioSessionStatus.activating, generation: generation);
  }

  /// Creates an active state.
  factory AudioSessionState.active({int generation = 0}) {
    return AudioSessionState.of(status: AudioSessionStatus.active, generation: generation);
  }

  /// Creates a deactivating state.
  factory AudioSessionState.deactivating({int generation = 0}) {
    return AudioSessionState.of(status: AudioSessionStatus.deactivating, generation: generation);
  }

  /// Creates an interrupted state.
  factory AudioSessionState.interrupted({int generation = 0}) {
    return AudioSessionState.of(status: AudioSessionStatus.interrupted, generation: generation);
  }

  /// Creates an error state.
  factory AudioSessionState.error({int generation = 0}) {
    return AudioSessionState.of(status: AudioSessionStatus.error, generation: generation);
  }

  /// Creates a disposed state.
  factory AudioSessionState.disposed({int generation = 0}) {
    return AudioSessionState.of(status: AudioSessionStatus.disposed, generation: generation);
  }

  AudioSessionState._();

  /// A session nobody has activated yet reads as inactive at generation zero
  /// rather than as missing data.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(AudioSessionStateBuilder builder) => builder
    ..status = AudioSessionStatus.inactive
    ..generation = 0;

  /// Current session lifecycle status.
  AudioSessionStatus get status;

  /// Monotonically increasing session lifecycle generation.
  ///
  /// Higher-level coordinators can use this value to ignore asynchronous
  /// callbacks belonging to an older session lifecycle, so it takes part in
  /// equality along with [status].
  int get generation;

  /// Whether the session is currently active.
  bool get isActive => status == AudioSessionStatus.active;

  /// Whether the session is currently inactive.
  bool get isInactive => status == AudioSessionStatus.inactive;

  /// Whether activation is in progress.
  bool get isActivating => status == AudioSessionStatus.activating;

  /// Whether deactivation is in progress.
  bool get isDeactivating => status == AudioSessionStatus.deactivating;

  /// Whether the session has been interrupted.
  bool get isInterrupted => status == AudioSessionStatus.interrupted;

  /// Whether the session encountered an error.
  bool get hasError => status == AudioSessionStatus.error;

  /// Whether the session has been disposed.
  bool get isDisposed => status == AudioSessionStatus.disposed;

  /// Whether the session is in a transitional lifecycle state.
  bool get isTransitioning => status == AudioSessionStatus.activating || status == AudioSessionStatus.deactivating;
}
