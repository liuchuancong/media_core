import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/audio/audio_focus_status.dart' show AudioFocusStatus;

part 'audio_focus_state.g.dart';

/// Immutable snapshot of the current audio-focus state.
///
/// The snapshot is intentionally small. Platform-specific information such as
/// native focus constants, interruption reasons, or route-change metadata
/// should remain outside the core abstraction.
abstract class AudioFocusState implements Built<AudioFocusState, AudioFocusStateBuilder> {
  /// Builds AudioFocusState from a [updates] callback — the codegen entry.
  factory AudioFocusState([void Function(AudioFocusStateBuilder)? updates]) = _$AudioFocusState;

  /// Creates an audio-focus state.
  factory AudioFocusState.of({AudioFocusStatus status = AudioFocusStatus.idle, int generation = 0}) {
    return AudioFocusState((builder) => builder..status = status..generation = generation);
  }

  /// Creates an idle state.
  factory AudioFocusState.idle({int generation = 0}) {
    return AudioFocusState.of(generation: generation);
  }

  /// Creates a state indicating that a focus request is in progress.
  factory AudioFocusState.requesting({int generation = 0}) {
    return AudioFocusState.of(status: AudioFocusStatus.requesting, generation: generation);
  }

  /// Creates a focused state.
  factory AudioFocusState.focused({int generation = 0}) {
    return AudioFocusState.of(status: AudioFocusStatus.focused, generation: generation);
  }

  /// Creates a generic lost-focus state.
  factory AudioFocusState.lost({int generation = 0}) {
    return AudioFocusState.of(status: AudioFocusStatus.lost, generation: generation);
  }

  /// Creates a temporarily lost-focus state.
  factory AudioFocusState.transientLoss({int generation = 0}) {
    return AudioFocusState.of(status: AudioFocusStatus.transientLoss, generation: generation);
  }

  /// Creates a permanently lost-focus state.
  factory AudioFocusState.permanentLoss({int generation = 0}) {
    return AudioFocusState.of(status: AudioFocusStatus.permanentLoss, generation: generation);
  }

  /// Creates an abandoned-focus state.
  factory AudioFocusState.abandoned({int generation = 0}) {
    return AudioFocusState.of(status: AudioFocusStatus.abandoned, generation: generation);
  }

  /// Creates an error state.
  factory AudioFocusState.error({int generation = 0}) {
    return AudioFocusState.of(status: AudioFocusStatus.error, generation: generation);
  }

  /// Creates a disposed state.
  factory AudioFocusState.disposed({int generation = 0}) {
    return AudioFocusState.of(status: AudioFocusStatus.disposed, generation: generation);
  }

  AudioFocusState._();

  /// Anything the platform has not reported yet reads as idle focus at
  /// generation zero rather than as missing data.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(AudioFocusStateBuilder builder) => builder
    ..status = AudioFocusStatus.idle
    ..generation = 0;

  /// Current focus status.
  AudioFocusStatus get status;

  /// Monotonically increasing generation associated with the focus lifecycle.
  ///
  /// A generation allows higher-level coordinators to distinguish callbacks
  /// belonging to an older focus lifecycle from callbacks belonging to the
  /// current one. It therefore also takes part in equality: two otherwise
  /// identical focus states from different generations must stay
  /// distinguishable to those coordinators.
  int get generation;

  /// Whether focus is currently held.
  bool get hasFocus => status == AudioFocusStatus.focused;

  /// Whether focus has been lost.
  bool get isLost =>
      status == AudioFocusStatus.lost ||
      status == AudioFocusStatus.transientLoss ||
      status == AudioFocusStatus.permanentLoss;

  /// Whether focus is temporarily unavailable.
  bool get isTemporarilyLost => status == AudioFocusStatus.transientLoss || status == AudioFocusStatus.lost;

  /// Whether focus must be requested again explicitly.
  bool get requiresRequest => status == AudioFocusStatus.permanentLoss || status == AudioFocusStatus.abandoned;

  /// Whether a focus request is currently in progress.
  bool get isRequesting => status == AudioFocusStatus.requesting;

  /// Whether the focus subsystem encountered an error.
  bool get hasError => status == AudioFocusStatus.error;

  /// Whether the focus lifecycle is inactive.
  bool get isInactive => status == AudioFocusStatus.idle || status == AudioFocusStatus.abandoned;

  /// Whether the focus lifecycle has been permanently disposed.
  bool get isDisposed => status == AudioFocusStatus.disposed;

  /// Whether the focus lifecycle is transitioning.
  bool get isTransitioning => status == AudioFocusStatus.requesting;
}
