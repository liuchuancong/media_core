import 'package:built_value/built_value.dart';

part 'platform_lifecycle.g.dart';

/// Describes platform lifecycle capabilities.
///
/// [PlatformLifecycle] represents what lifecycle
/// behaviors are supported by the current platform.
///
/// Responsibilities:
///
/// - background playback capability
/// - suspend/resume capability
/// - lifecycle transition support
///
/// It does not:
///
/// - observe lifecycle events
/// - control player state
///
/// Those belong to:
///
/// - LifecycleManager
/// - PlayerSession
abstract class PlatformLifecycle implements Built<PlatformLifecycle, PlatformLifecycleBuilder> {
  /// Builds PlatformLifecycle from a [updates] callback — the codegen entry.
  factory PlatformLifecycle([void Function(PlatformLifecycleBuilder)? updates]) = _$PlatformLifecycle;

  /// Creates PlatformLifecycle from the fields it describes.
  factory PlatformLifecycle.of({
    bool backgroundPlayback = false,
    bool pauseOnInactive = true,
    bool pauseOnBackground = true,
    bool resumeOnForeground = true,
    bool keepAudioAlive = false,
    bool suspendAllowed = true,
    bool restoreAfterSuspend = true,
  }) {
    return PlatformLifecycle(
      (builder) => builder
        ..backgroundPlayback = backgroundPlayback
        ..pauseOnInactive = pauseOnInactive
        ..pauseOnBackground = pauseOnBackground
        ..resumeOnForeground = resumeOnForeground
        ..keepAudioAlive = keepAudioAlive
        ..suspendAllowed = suspendAllowed
        ..restoreAfterSuspend = restoreAfterSuspend,
    );
  }

  PlatformLifecycle._();

  /// Anything the platform does not report keeps the documented default
  /// rather than turning into null.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlatformLifecycleBuilder builder) => builder
    ..backgroundPlayback = false
    ..pauseOnInactive = true
    ..pauseOnBackground = true
    ..resumeOnForeground = true
    ..keepAudioAlive = false
    ..suspendAllowed = true
    ..restoreAfterSuspend = true;

  /// Whether playback can continue in background.
  ///
  /// Example:
  ///
  /// - mobile audio playback
  /// - desktop background playback
  bool get backgroundPlayback;

  /// Whether player should pause when app becomes inactive.
  bool get pauseOnInactive;

  /// Whether player should pause when app enters background.
  bool get pauseOnBackground;

  /// Whether playback should resume after foreground.
  bool get resumeOnForeground;

  /// Whether audio can continue when UI disappears.
  bool get keepAudioAlive;

  /// Whether player resources can be suspended.
  bool get suspendAllowed;

  /// Whether player can restore after suspension.
  bool get restoreAfterSuspend;

  /// Whether background playback is supported.
  bool get canBackgroundPlay {
    return backgroundPlayback;
  }

  /// Whether automatic resume is supported.
  bool get canAutoResume {
    return resumeOnForeground && restoreAfterSuspend;
  }

  /// Whether app lifecycle control is available.
  bool get canControlLifecycle {
    return pauseOnInactive || pauseOnBackground;
  }
}
