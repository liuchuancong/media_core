import 'package:built_value/built_value.dart';

part 'platform_pip.g.dart';

/// Describes picture-in-picture capabilities.
///
/// [PlatformPip] represents whether the current
/// platform supports floating playback.
///
/// Responsibilities:
///
/// - describe PiP support
/// - describe window behavior
/// - describe interaction capability
///
/// It does not:
///
/// - enter PiP mode
/// - manage floating window
///
/// Those belong to:
///
/// - PipController
/// - Presentation layer
abstract class PlatformPip implements Built<PlatformPip, PlatformPipBuilder> {
  /// Builds PlatformPip from a [updates] callback — the codegen entry.
  factory PlatformPip([void Function(PlatformPipBuilder)? updates]) = _$PlatformPip;

  /// Creates PlatformPip from the fields it describes.
  factory PlatformPip.of({
    bool enabled = false,
    bool systemPip = false,
    bool customFloatingWindow = false,
    bool autoEnter = false,
    bool backgroundAudio = false,
    bool resizeable = true,
    bool keepControls = false,
  }) {
    return PlatformPip(
      (builder) => builder
        ..enabled = enabled
        ..systemPip = systemPip
        ..customFloatingWindow = customFloatingWindow
        ..autoEnter = autoEnter
        ..backgroundAudio = backgroundAudio
        ..resizeable = resizeable
        ..keepControls = keepControls,
    );
  }

  PlatformPip._();

  /// Anything the platform does not report keeps the documented default
  /// rather than turning into null.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlatformPipBuilder builder) => builder
    ..enabled = false
    ..systemPip = false
    ..customFloatingWindow = false
    ..autoEnter = false
    ..backgroundAudio = false
    ..resizeable = true
    ..keepControls = false;

  /// Whether PiP feature is enabled.
  bool get enabled;

  /// Whether native system PiP is supported.
  ///
  /// Examples:
  ///
  /// - Android PiP
  /// - iOS PiP
  bool get systemPip;

  /// Whether custom floating window is supported.
  ///
  /// Examples:
  ///
  /// - desktop floating player
  /// - flutter_floating
  bool get customFloatingWindow;

  /// Whether player can automatically enter PiP.
  bool get autoEnter;

  /// Whether audio can continue in PiP.
  bool get backgroundAudio;

  /// Whether PiP window can resize.
  bool get resizeable;

  /// Whether playback controls remain visible.
  bool get keepControls;

  /// Whether any PiP mode is available.
  bool get available {
    return enabled && (systemPip || customFloatingWindow);
  }

  /// Whether native PiP is preferred.
  bool get preferSystem {
    return systemPip;
  }

  /// Whether custom floating mode is available.
  bool get canFloat {
    return customFloatingWindow;
  }

  /// Whether background playback is possible.
  bool get canContinuePlayback {
    return backgroundAudio;
  }
}
