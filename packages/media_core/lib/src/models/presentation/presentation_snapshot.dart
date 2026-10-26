import 'package:built_value/built_value.dart';
import 'package:media_core/src/geometry/value/video_orientation.dart';
import 'package:media_core/src/presentation/descriptor/presentation_capabilities.dart';
import 'package:media_core/src/presentation/descriptor/presentation_mode.dart';
import 'package:media_core/src/presentation/state/presentation_state.dart' show PresentationState;

part 'presentation_snapshot.g.dart';

/// Immutable snapshot of presentation state.
///
/// Snapshot is a read-only view of the
/// current presentation subsystem.
///
/// It is used by:
///
/// - UI layer
/// - PlayerManager
/// - PlayerIdentity widgets
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
abstract class PresentationSnapshot implements Built<PresentationSnapshot, PresentationSnapshotBuilder> {
  /// Builds PresentationSnapshot from a [updates] callback — the codegen entry.
  factory PresentationSnapshot([void Function(PresentationSnapshotBuilder)? updates]) = _$PresentationSnapshot;

  /// Creates a presentation snapshot from its fields.
  factory PresentationSnapshot.of({
    PresentationMode mode = PresentationMode.normal,
    PresentationMode? targetMode,
    PresentationCapabilities capabilities = const PresentationCapabilities(),
    VideoOrientation orientation = VideoOrientation.unknown,
    bool transitioning = false,
    bool enabled = true,
    bool available = true,
    int generation = 0,
    String? error,
  }) {
    return PresentationSnapshot(
      (builder) => builder
        ..mode = mode
        ..targetMode = targetMode
        ..capabilities = capabilities
        ..orientation = orientation
        ..transitioning = transitioning
        ..enabled = enabled
        ..available = available
        ..generation = generation
        ..error = error,
    );
  }

  /// Creates initial snapshot.
  factory PresentationSnapshot.initial() {
    return PresentationSnapshot.of();
  }

  PresentationSnapshot._();

  /// A snapshot nobody filled in reports normal mode, enabled and available,
  /// at generation zero, with no transition running and no error.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PresentationSnapshotBuilder builder) => builder
    ..mode = PresentationMode.normal
    ..capabilities = const PresentationCapabilities()
    ..orientation = VideoOrientation.unknown
    ..transitioning = false
    ..enabled = true
    ..available = true
    ..generation = 0;

  /// Current active presentation mode.
  ///
  /// This represents the mode that has
  /// successfully completed.
  PresentationMode get mode;

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
  PresentationMode? get targetMode;

  /// Platform capabilities.
  ///
  /// Describes supported presentation features.
  PresentationCapabilities get capabilities;

  /// Orientation of the media being presented. See [PresentationState.orientation].
  VideoOrientation get orientation;

  /// Whether presentation transition
  /// is running.
  bool get transitioning;

  /// Whether presentation subsystem
  /// is enabled.
  bool get enabled;

  /// Whether presentation is available.
  bool get available;

  /// Lifecycle generation.
  ///
  /// Used to identify stale async
  /// callbacks.
  int get generation;

  /// Last presentation error.
  String? get error;

  // ============================================================
  // Current mode helpers
  // ============================================================

  /// Whether fullscreen active.
  bool get isFullscreen => mode == PresentationMode.fullscreen;

  /// Whether the player currently fills the window without system fullscreen.
  bool get isWindowFullscreen => mode == PresentationMode.windowFullscreen;

  /// Whether either fullscreen variant is active.
  bool get isAnyFullscreen => isFullscreen || isWindowFullscreen;

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

  /// Whether switching to window-level fullscreen.
  bool get isTransitioningToWindowFullscreen => transitioning && targetMode == PresentationMode.windowFullscreen;

  /// Whether transition targeting PiP.
  bool get isTransitioningToPip => transitioning && targetMode == PresentationMode.pip;

  /// Whether transition targeting floating.
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
