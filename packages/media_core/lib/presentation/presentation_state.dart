import 'presentation_mode.dart';
import 'presentation_capabilities.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_state.freezed.dart';

/// Represents current presentation lifecycle state.
///
/// This state only describes the logical presentation
/// status of the media player.
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
    /// Current presentation mode.
    @Default(PresentationMode.normal) PresentationMode mode,

    /// Current capabilities.
    @Default(PresentationCapabilities()) PresentationCapabilities capabilities,

    /// Whether presentation transition
    /// is currently running.
    @Default(false) bool transitioning,

    /// Whether presentation subsystem
    /// is enabled.
    @Default(true) bool enabled,

    /// Whether presentation is available.
    @Default(true) bool available,

    /// Lifecycle generation.
    ///
    /// Used to ignore stale asynchronous
    /// callbacks from platform adapters.
    @Default(0) int generation,

    /// Last presentation error.
    String? error,
  }) = _PresentationState;

  const PresentationState._();

  /// Initial presentation state.
  factory PresentationState.initial() {
    return const PresentationState(
      mode: PresentationMode.normal,
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

  /// Whether floating mode is active.
  bool get isFloating => mode == PresentationMode.floating;

  /// Whether player is in normal mode.
  bool get isNormal => mode == PresentationMode.normal;

  /// Whether transition is running.
  bool get isTransitioning => transitioning;

  /// Whether state contains an error.
  bool get hasError => error != null;

  /// Whether current mode is supported.
  bool get isSupported => capabilities.supports(mode);

  /// Whether a presentation request
  /// can be accepted.
  bool get canRequestChange => enabled && available && !transitioning && !hasError;

  /// Creates a state after successful transition.
  PresentationState completed(PresentationMode mode) {
    return copyWith(mode: mode, transitioning: false, error: null);
  }

  /// Creates a transition state.
  PresentationState withTransition(PresentationMode mode) {
    return copyWith(mode: mode, transitioning: true, error: null);
  }

  /// Creates an error state.
  PresentationState failed(String message) {
    return copyWith(transitioning: false, error: message);
  }
}
