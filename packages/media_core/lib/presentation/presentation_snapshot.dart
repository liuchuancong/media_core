import 'presentation_mode.dart';
import 'presentation_capabilities.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_snapshot.freezed.dart';

/// Immutable snapshot of presentation subsystem.
///
/// Snapshot represents a point-in-time view of the
/// presentation lifecycle.
///
/// It does not trigger transitions and does not
/// communicate with platform APIs.
///
/// Used by:
///
/// - PresentationController
/// - MediaManager
/// - UI layer
@freezed
abstract class PresentationSnapshot with _$PresentationSnapshot {
  const factory PresentationSnapshot({
    /// Current presentation mode.
    @Default(PresentationMode.normal) PresentationMode mode,

    /// Current presentation capabilities.
    @Default(PresentationCapabilities()) PresentationCapabilities capabilities,

    /// Whether a transition is running.
    @Default(false) bool transitioning,

    /// Whether presentation system is enabled.
    @Default(true) bool enabled,

    /// Current lifecycle generation.
    ///
    /// Used to reject stale async callbacks.
    @Default(0) int generation,

    /// Last presentation error.
    String? error,
  }) = _PresentationSnapshot;

  const PresentationSnapshot._();

  /// Initial snapshot.
  factory PresentationSnapshot.initial() {
    return const PresentationSnapshot(
      mode: PresentationMode.normal,
      capabilities: PresentationCapabilities(),
      transitioning: false,
      enabled: true,
      generation: 0,
    );
  }

  /// Whether fullscreen is active.
  bool get isFullscreen => mode == PresentationMode.fullscreen;

  /// Whether PiP is active.
  bool get isPip => mode == PresentationMode.pip;

  /// Whether floating mode is active.
  bool get isFloating => mode == PresentationMode.floating;

  /// Whether normal presentation is active.
  bool get isNormal => mode == PresentationMode.normal;

  /// Whether snapshot contains an error.
  bool get hasError => error != null;

  /// Whether current mode is supported.
  bool get isSupported => capabilities.supports(mode);

  /// Whether transition can start.
  bool get canChange => enabled && !transitioning && !hasError;
}
