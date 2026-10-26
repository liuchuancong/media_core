import 'package:built_value/built_value.dart';

part 'fullscreen_state.g.dart';

/// Describes fullscreen lifecycle state.
///
/// This state only represents the logical fullscreen lifecycle.
///
/// It does not directly control:
///
/// - system UI
/// - orientation
/// - platform fullscreen APIs
///
/// Platform adapters are responsible for applying fullscreen changes.
abstract class FullscreenState implements Built<FullscreenState, FullscreenStateBuilder> {
  /// Builds FullscreenState from a [updates] callback — the codegen entry.
  factory FullscreenState([void Function(FullscreenStateBuilder)? updates]) = _$FullscreenState;

  /// Creates a fullscreen state from its individual flags.
  factory FullscreenState.of({
    bool active = false,
    bool transitioning = false,
    bool available = true,
    int generation = 0,
    String? error,
  }) {
    return FullscreenState(
      (builder) => builder
        ..active = active
        ..transitioning = transitioning
        ..available = available
        ..generation = generation
        ..error = error,
    );
  }

  /// Initial fullscreen state.
  factory FullscreenState.initial() => FullscreenState.of();

  FullscreenState._();

  /// Not active, not transitioning, offered by the platform, at generation
  /// zero and error-free until a driver reports otherwise.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(FullscreenStateBuilder builder) => builder
    ..active = false
    ..transitioning = false
    ..available = true
    ..generation = 0;

  /// Whether fullscreen is currently active.
  bool get active;

  /// Whether fullscreen transition is running.
  bool get transitioning;

  /// Whether fullscreen feature is available.
  bool get available;

  /// Lifecycle generation.
  ///
  /// Used to ignore stale async callbacks.
  int get generation;

  /// Last fullscreen error.
  String? get error;

  /// Whether fullscreen is active.
  bool get isFullscreen => active;

  /// Whether transition is running.
  bool get isTransitioning => transitioning;

  /// Whether fullscreen failed.
  bool get hasError => error != null;

  /// Whether fullscreen can be entered.
  bool get canEnter => available && !active && !transitioning;

  /// Whether fullscreen can be exited.
  bool get canExit => available && active && !transitioning;

  /// A copy with the given fields replaced; an omitted field keeps its current
  /// value. That is freezed's reading, kept deliberately: controllers call
  /// `copyWith(error: null)` meaning to clear, and today that argument is
  /// ignored, so switching to "null clears" here would change behaviour rather
  /// than migrate it.
  FullscreenState copyWith({bool? active, bool? transitioning, bool? available, int? generation, String? error}) {
    return rebuild((builder) => builder
      ..active = active ?? builder.active
      ..transitioning = transitioning ?? builder.transitioning
      ..available = available ?? builder.available
      ..generation = generation ?? builder.generation
      ..error = error ?? builder.error);
  }
}
