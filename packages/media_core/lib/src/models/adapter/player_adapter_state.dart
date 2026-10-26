import 'package:built_value/built_value.dart';

part 'player_adapter_state.g.dart';

/// Runtime state of a player adapter.
///
/// [PlayerAdapterState] represents the current
/// playback backend state.
///
/// Responsibilities:
///
/// - expose adapter state snapshot
/// - provide immutable state updates
///
/// It does not:
///
/// - execute playback commands
/// - dispatch events
/// - collect metrics
///
/// Those belong to:
///
/// - PlayerAdapter
/// - PlayerAdapterEvent
/// - PlayerAdapterMetrics
abstract class PlayerAdapterState implements Built<PlayerAdapterState, PlayerAdapterStateBuilder> {
  /// Builds PlayerAdapterState from a [updates] callback — the codegen entry.
  factory PlayerAdapterState([void Function(PlayerAdapterStateBuilder)? updates]) = _$PlayerAdapterState;

  /// Creates adapter state.
  factory PlayerAdapterState.of({
    bool initialized = false,
    bool opened = false,
    bool playing = false,
    bool paused = false,
    bool buffering = false,
    bool completed = false,
    bool hasError = false,
    Duration position = Duration.zero,
    Duration? duration,
    double volume = 1.0,
    double rate = 1.0,
    int? width,
    int? height,
    String? errorMessage,
  }) {
    return PlayerAdapterState(
      (builder) => builder
        ..initialized = initialized
        ..opened = opened
        ..playing = playing
        ..paused = paused
        ..buffering = buffering
        ..completed = completed
        ..hasError = hasError
        ..position = position
        ..duration = duration
        ..volume = volume
        ..rate = rate
        ..width = width
        ..height = height
        ..errorMessage = errorMessage,
    );
  }

  /// Creates initial state.
  factory PlayerAdapterState.initial() {
    return PlayerAdapterState.of();
  }

  PlayerAdapterState._();

  /// A backend nobody has opened is idle at zero position, unit volume and
  /// unit rate, with nothing reported about duration or video size.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerAdapterStateBuilder builder) => builder
    ..initialized = false
    ..opened = false
    ..playing = false
    ..paused = false
    ..buffering = false
    ..completed = false
    ..hasError = false
    ..position = Duration.zero
    ..volume = 1.0
    ..rate = 1.0;

  /// Whether adapter is initialized.
  bool get initialized;

  /// Whether a source is opened.
  bool get opened;

  /// Whether playback is active.
  bool get playing;

  /// Whether playback is paused.
  bool get paused;

  /// Whether backend is buffering.
  bool get buffering;

  /// Whether playback completed.
  bool get completed;

  /// Whether adapter has error.
  bool get hasError;

  /// Current playback position.
  Duration get position;

  /// Current duration.
  Duration? get duration;

  /// Current volume.
  double get volume;

  /// Current playback rate.
  double get rate;

  /// Video width.
  int? get width;

  /// Video height.
  int? get height;

  /// Error message.
  String? get errorMessage;
}

/// Extensions for adapter state.
extension PlayerAdapterStateExtension on PlayerAdapterState {
  /// Whether adapter is ready for playback.
  bool get ready {
    return initialized && opened && !hasError;
  }

  /// Whether video information exists.
  bool get hasVideoSize {
    return width != null && height != null;
  }

  /// Whether duration is available.
  bool get hasDuration {
    return duration != null;
  }

  /// Whether playback is active.
  bool get active {
    return playing && !hasError;
  }

  /// Whether state is terminal.
  bool get finished {
    return completed || hasError;
  }

  /// Video aspect ratio.
  double? get aspectRatio {
    if (!hasVideoSize) {
      return null;
    }

    return width! / height!;
  }
}
