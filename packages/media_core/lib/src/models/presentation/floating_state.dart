import 'package:built_value/built_value.dart';

part 'floating_state.g.dart';

/// Represents floating window presentation lifecycle state.
///
/// This state only describes the logical floating window lifecycle.
///
/// It does not:
///
/// - create overlay windows
/// - manage window position
/// - control native window APIs
///
/// Platform adapters are responsible for applying
/// floating window operations.
abstract class FloatingState implements Built<FloatingState, FloatingStateBuilder> {
  /// Builds FloatingState from a [updates] callback — the codegen entry.
  factory FloatingState([void Function(FloatingStateBuilder)? updates]) = _$FloatingState;

  /// Creates a floating state from its individual flags.
  factory FloatingState.of({
    bool active = false,
    bool transitioning = false,
    bool available = false,
    bool enabled = true,
    int generation = 0,
    String? error,
  }) {
    return FloatingState(
      (builder) => builder
        ..active = active
        ..transitioning = transitioning
        ..available = available
        ..enabled = enabled
        ..generation = generation
        ..error = error,
    );
  }

  /// Initial floating state.
  factory FloatingState.initial() {
    return FloatingState.of();
  }

  FloatingState._();

  /// No window is up, nothing is moving, the platform may not offer it, the
  /// switch is on, and generation starts at zero.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(FloatingStateBuilder builder) => builder
    ..active = false
    ..transitioning = false
    ..available = false
    ..enabled = true
    ..generation = 0;

  /// Whether floating mode is active.
  bool get active;

  /// Whether floating transition is running.
  bool get transitioning;

  /// Whether floating window is supported.
  bool get available;

  /// Whether floating mode is enabled.
  ///
  /// Controlled by:
  ///
  /// - user settings
  /// - application policy
  bool get enabled;

  /// Lifecycle generation.
  ///
  /// Used to ignore stale async callbacks.
  int get generation;

  /// Last floating error.
  String? get error;

  /// Whether floating mode is active.
  bool get isFloating => active;

  /// Whether transition is running.
  bool get isTransitioning => transitioning;

  /// Whether state contains error.
  bool get hasError => error != null;

  /// Whether floating mode can enter.
  bool get canEnter => available && enabled && !active && !transitioning;

  /// Whether floating mode can exit.
  bool get canExit => active && !transitioning;

  /// Whether floating capability exists.
  bool get supportsFloating => available;

  /// A copy with the given fields replaced; an omitted field keeps its current
  /// value. That is freezed's reading, kept because callers rely on it — the
  /// places that meant to clear the error now say so with an explicit
  /// `rebuild`, instead of passing a null this method could not tell apart
  /// from an omission.
  FloatingState copyWith({bool? active, bool? transitioning, bool? available, bool? enabled, int? generation, String? error}) {
    return rebuild((builder) => builder
      ..active = active ?? builder.active
      ..transitioning = transitioning ?? builder.transitioning
      ..available = available ?? builder.available
      ..enabled = enabled ?? builder.enabled
      ..generation = generation ?? builder.generation
      ..error = error ?? builder.error);
  }
}
