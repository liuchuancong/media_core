import 'presentation_mode.dart';
import 'presentation_capabilities.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_snapshot.freezed.dart';

/// Immutable snapshot of presentation state.
///
/// Snapshot is a read-only view of the
/// current presentation subsystem.
///
/// It is used by:
///
/// - UI layer
/// - PlayerManager
/// - Player widgets
/// - settings pages
///
/// Snapshot does not:
///
/// - perform transitions
/// - call platform APIs
/// - modify presentation state
/// - handle lifecycle
///
/// The source of truth remains:
///
/// PresentationController
@freezed
abstract class PresentationSnapshot with _$PresentationSnapshot {
  const factory PresentationSnapshot({
    /// Current active presentation mode.
    ///
    /// This represents the mode that has
    /// successfully completed.
    @Default(PresentationMode.normal) PresentationMode mode,

    /// Requested target mode.
    ///
    /// During transition:
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

    /// Platform capabilities.
    ///
    /// Describes supported presentation features.
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
    /// Used to identify stale async
    /// callbacks.
    @Default(0) int generation,

    /// Last presentation error.
    String? error,
  }) = _PresentationSnapshot;

  const PresentationSnapshot._();

  /// Creates initial snapshot.
  factory PresentationSnapshot.initial() {
    return const PresentationSnapshot(
      mode: PresentationMode.normal,
      targetMode: null,
      capabilities: PresentationCapabilities(),
      transitioning: false,
      enabled: true,
      available: true,
      generation: 0,
    );
  }

  // ============================================================
  // Current mode helpers
  // ============================================================

  /// Whether fullscreen active.
  bool get isFullscreen => mode == PresentationMode.fullscreen;

  /// Whether PiP active.
  bool get isPip => mode == PresentationMode.pip;

  /// Whether floating active.
  bool get isFloating => mode == PresentationMode.floating;

  /// Whether normal mode active.
  bool get isNormal => mode == PresentationMode.normal;

  // ============================================================
  // Transition helpers
  // ============================================================

  /// Whether transition is running.
  bool get isTransitioning => transitioning;

  /// Whether transition is targeting fullscreen.
  ///
  /// Example:
  ///
  /// current:
  /// normal
  ///
  /// target:
  /// fullscreen
  ///
  /// transitioning:
  /// true
  bool get isTransitioningToFullscreen => transitioning && targetMode == PresentationMode.fullscreen;

  /// Whether transition is targeting PiP.
  bool get isTransitioningToPip => transitioning && targetMode == PresentationMode.pip;

  /// Whether transition is targeting floating.
  bool get isTransitioningToFloating => transitioning && targetMode == PresentationMode.floating;

  /// Whether transition has target.
  bool get hasTarget => targetMode != null;

  // ============================================================
  // State validation helpers
  // ============================================================

  /// Whether state contains error.
  bool get hasError => error != null;

  /// Whether current mode is supported.
  bool get isSupported => capabilities.supports(mode);

  /// Whether presentation can change.
  ///
  /// A request cannot start when:
  ///
  /// - disabled
  /// - unavailable
  /// - already transitioning
  /// - previous error exists
  bool get canChange => enabled && available && !transitioning && !hasError;

  /// Whether target mode is supported.
  bool get isTargetSupported => targetMode == null || capabilities.supports(targetMode!);

  /// Whether snapshot is idle.
  ///
  /// Idle means:
  ///
  /// - no transition
  /// - no error
  bool get isIdle => !transitioning && !hasError;
}
