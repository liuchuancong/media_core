import 'package:built_value/built_value.dart';

part 'pip_state.g.dart';

/// Represents picture-in-picture lifecycle state.
///
/// This state only describes the logical PiP lifecycle.
///
/// It does not directly invoke platform PiP APIs.
///
/// Platform adapters are responsible for:
///
/// - entering PiP
/// - leaving PiP
/// - listening to native PiP callbacks
abstract class PipState implements Built<PipState, PipStateBuilder> {
  /// Builds PipState from a [updates] callback — the codegen entry.
  factory PipState([void Function(PipStateBuilder)? updates]) = _$PipState;

  /// Creates a PiP state from its individual flags.
  factory PipState.of({
    bool active = false,
    bool transitioning = false,
    bool available = false,
    bool enabled = true,
    int generation = 0,
    String? error,
  }) {
    return PipState(
      (builder) => builder
        ..active = active
        ..transitioning = transitioning
        ..available = available
        ..enabled = enabled
        ..generation = generation
        ..error = error,
    );
  }

  /// Initial PiP state.
  factory PipState.initial() {
    return PipState.of();
  }

  PipState._();

  /// A session nobody has reported on is inactive, not transitioning, not
  /// available, switchable on, at generation zero and error-free.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PipStateBuilder builder) => builder
    ..active = false
    ..transitioning = false
    ..available = false
    ..enabled = true
    ..generation = 0;

  /// Whether PiP is currently active.
  bool get active;

  /// Whether a PiP transition is running.
  bool get transitioning;

  /// Whether PiP is supported.
  bool get available;

  /// Whether PiP is currently possible.
  ///
  /// Some platforms support PiP but temporarily
  /// cannot enter it.
  bool get enabled;

  /// Lifecycle generation.
  ///
  /// Used to ignore stale async callbacks.
  int get generation;

  /// Last PiP error.
  String? get error;

  /// Whether PiP is active.
  bool get isPip => active;

  /// Whether PiP transition is running.
  bool get isTransitioning => transitioning;

  /// Whether PiP failed.
  bool get hasError => error != null;

  /// Whether PiP can be entered.
  bool get canEnter => available && enabled && !active && !transitioning;

  /// Whether PiP can be exited.
  bool get canExit => active && !transitioning;

  /// Whether PiP capability exists.
  bool get supportsPip => available;

  /// A copy with the given fields replaced; an omitted field keeps its current
  /// value. That is freezed's reading, kept deliberately: controllers call
  /// `copyWith(error: null)` meaning to clear, and today that argument is
  /// ignored, so switching to "null clears" here would change behaviour rather
  /// than migrate it.
  PipState copyWith({bool? active, bool? transitioning, bool? available, bool? enabled, int? generation, String? error}) {
    return rebuild((builder) => builder
      ..active = active ?? builder.active
      ..transitioning = transitioning ?? builder.transitioning
      ..available = available ?? builder.available
      ..enabled = enabled ?? builder.enabled
      ..generation = generation ?? builder.generation
      ..error = error ?? builder.error);
  }
}
