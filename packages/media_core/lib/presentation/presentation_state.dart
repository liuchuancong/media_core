import 'presentation_mode.dart';
import 'presentation_capabilities.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_state.freezed.dart';

/// Represents current presentation lifecycle state.
///
/// This state only describes the logical presentation
/// lifecycle of the media player.
///
/// It does not:
///
/// - enter fullscreen
/// - create PiP window
/// - create floating window
/// - control system UI
///
/// Platform adapters are responsible for applying
/// native presentation operations.
@freezed
abstract class PresentationState with _$PresentationState {
  const factory PresentationState({
    /// Current active presentation mode.
    ///
    /// This represents the mode that has
    /// successfully completed.
    @Default(PresentationMode.normal) PresentationMode mode,

    /// Target presentation mode.
    ///
    /// When transitioning:
    ///
    /// Example:
    ///
    /// mode:
    /// fullscreen
    ///
    /// targetMode:
    /// pip
    ///
    /// transitioning:
    /// true
    ///
    PresentationMode? targetMode,

    /// Current capabilities.
    @Default(PresentationCapabilities()) PresentationCapabilities capabilities,

    /// Whether presentation transition
    /// is running.
    @Default(false) bool transitioning,

    /// Whether presentation subsystem
    /// is enabled.
    @Default(true) bool enabled,

    /// Whether presentation is available.
    @Default(true) bool available,

    /// Lifecycle generation.
    ///
    /// Used to ignore stale async
    /// callbacks from adapters.
    @Default(0) int generation,

    /// Last presentation error.
    String? error,
  }) = _PresentationState;

  const PresentationState._();

  /// Initial state.
  factory PresentationState.initial() {
    return const PresentationState(
      mode: PresentationMode.normal,
      targetMode: null,
      transitioning: false,
      enabled: true,
      available: true,
      generation: 0,
    );
  }

  /// Whether fullscreen is active.
  bool get isFullscreen => mode == PresentationMode.fullscreen;

  /// Whether PiP is active.
  bool get isPip => mode == PresentationMode.pip;

  /// Whether floating is active.
  bool get isFloating => mode == PresentationMode.floating;

  /// Whether normal mode is active.
  bool get isNormal => mode == PresentationMode.normal;

  /// Whether transition running.
  bool get isTransitioning => transitioning;

  /// Whether state has error.
  bool get hasError => error != null;

  /// Whether current mode is supported.
  bool get isSupported => capabilities.supports(mode);

  /// Whether target mode exists.
  bool get hasTarget => targetMode != null;

  /// Whether request can be accepted.
  bool get canRequestChange => enabled && available && !transitioning && !hasError;

  /// Creates transition state.
  PresentationState transitioningTo(PresentationMode target) {
    return copyWith(targetMode: target, transitioning: true, error: null);
  }

  /// Completes transition.
  PresentationState completed(PresentationMode newMode) {
    return copyWith(mode: newMode, targetMode: null, transitioning: false, error: null);
  }

  /// Creates failed state.
  PresentationState failed(String message) {
    return copyWith(targetMode: null, transitioning: false, error: message);
  }
}
