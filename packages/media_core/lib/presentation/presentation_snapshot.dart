import 'presentation_mode.dart';
import 'presentation_capabilities.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_snapshot.freezed.dart';

/// Immutable snapshot of presentation subsystem.
///
/// Snapshot represents a point-in-time view of
/// presentation lifecycle.
///
/// It does not:
///
/// - trigger transitions
/// - call platform APIs
/// - modify state
///
/// Used by:
///
/// - PresentationController
/// - MediaManager
/// - UI layer
@freezed
abstract class PresentationSnapshot with _$PresentationSnapshot {
  const factory PresentationSnapshot({
    /// Current active presentation mode.
    ///
    /// This is the last successfully completed mode.
    @Default(PresentationMode.normal) PresentationMode mode,

    /// Target presentation mode.
    ///
    /// Exists while transition is running.
    ///
    /// Example:
    ///
    /// mode:
    /// normal
    ///
    /// targetMode:
    /// fullscreen
    ///
    /// transitioning:
    /// true
    PresentationMode? targetMode,

    /// Current capabilities.
    @Default(PresentationCapabilities()) PresentationCapabilities capabilities,

    /// Whether transition is running.
    @Default(false) bool transitioning,

    /// Whether presentation is enabled.
    @Default(true) bool enabled,

    /// Lifecycle generation.
    ///
    /// Used to ignore stale async callbacks.
    @Default(0) int generation,

    /// Last error.
    String? error,
  }) = _PresentationSnapshot;

  const PresentationSnapshot._();

  /// Initial snapshot.
  factory PresentationSnapshot.initial() {
    return const PresentationSnapshot(
      mode: PresentationMode.normal,
      targetMode: null,
      capabilities: PresentationCapabilities(),
      transitioning: false,
      enabled: true,
      generation: 0,
    );
  }

  /// Current mode helpers.

  bool get isFullscreen => mode == PresentationMode.fullscreen;

  bool get isPip => mode == PresentationMode.pip;

  bool get isFloating => mode == PresentationMode.floating;

  bool get isNormal => mode == PresentationMode.normal;

  /// Transition helpers.

  bool get hasTarget => targetMode != null;

  bool get isTransitioning => transitioning;

  bool get isTransitioningToFullscreen => transitioning && targetMode == PresentationMode.fullscreen;

  bool get isTransitioningToPip => transitioning && targetMode == PresentationMode.pip;

  bool get isTransitioningToFloating => transitioning && targetMode == PresentationMode.floating;

  /// Error helpers.

  bool get hasError => error != null;

  /// Capability check.

  bool get isSupported => capabilities.supports(mode);

  /// Whether request can start.

  bool get canChange => enabled && !transitioning && !hasError;
}
