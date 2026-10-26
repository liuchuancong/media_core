import 'package:built_value/built_value.dart';

part 'visibility_state.g.dart';

/// Runtime visibility state.
abstract class VisibilityState implements Built<VisibilityState, VisibilityStateBuilder> {
  /// Builds a state from a [updates] callback — the codegen entry.
  factory VisibilityState([void Function(VisibilityStateBuilder)? updates]) = _$VisibilityState;

  /// Creates visibility state from explicit values.
  factory VisibilityState.of({
    bool visible = false,
    double visibility = 0.0,
    bool inViewport = false,
    bool occluded = false,
  }) {
    return VisibilityState(
      (builder) => builder
        ..visible = visible
        ..visibility = visibility
        ..inViewport = inViewport
        ..occluded = occluded,
    );
  }

  VisibilityState._();

  /// A player nobody has measured is off screen: hidden, zero ratio,
  /// outside the viewport and not covered.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(VisibilityStateBuilder builder) => builder
    ..visible = false
    ..visibility = 0.0
    ..inViewport = false
    ..occluded = false;

  /// Whether widget is visible.
  bool get visible;

  /// Visibility ratio.
  ///
  /// Range:
  ///
  /// 0.0 - 1.0
  double get visibility;

  /// Whether player is inside viewport.
  bool get inViewport;

  /// Whether player is covered.
  bool get occluded;

  /// Whether the whole player is on screen.
  bool get isFullyVisible {
    return visibility >= 1.0;
  }

  /// Whether only part of the player is on screen.
  bool get isPartiallyVisible {
    return visibility > 0 && visibility < 1;
  }

  /// Whether none of the player is on screen.
  bool get isHidden {
    return visibility <= 0;
  }

  /// Applies a new visibility [value], treating any positive ratio as visible.
  VisibilityState update(double value) {
    return rebuild((builder) {
      builder
        ..visibility = value
        ..visible = value > 0;
    });
  }

  /// Marks the player visible without touching the ratio.
  VisibilityState show() {
    return rebuild((builder) => builder..visible = true);
  }

  /// Marks the player hidden and zeroes the ratio.
  VisibilityState hide() {
    return rebuild((builder) {
      builder
        ..visible = false
        ..visibility = 0;
    });
  }
}
