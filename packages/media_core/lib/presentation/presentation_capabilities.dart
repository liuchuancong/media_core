import 'presentation_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_capabilities.freezed.dart';

/// Describes supported presentation capabilities.
///
/// Capabilities describe what the current
/// environment supports.
///
/// They do not represent current presentation mode.
///
/// Responsibilities:
///
/// - fullscreen support
/// - PiP support
/// - floating support
///
/// Does not:
///
/// - perform transitions
/// - call platform APIs
/// - manage lifecycle
@freezed
abstract class PresentationCapabilities with _$PresentationCapabilities {
  const factory PresentationCapabilities({
    /// Whether fullscreen is supported.
    @Default(true) bool fullscreen,

    /// Whether picture-in-picture is supported.
    @Default(false) bool pip,

    /// Whether floating window is supported.
    @Default(false) bool floating,
  }) = _PresentationCapabilities;

  const PresentationCapabilities._();

  /// Default capabilities.
  factory PresentationCapabilities.initial() {
    return const PresentationCapabilities(fullscreen: true, pip: false, floating: false);
  }

  /// Whether advanced presentation exists.
  bool get supportsAdvancedPresentation => fullscreen || pip || floating;

  /// Checks whether mode is supported.
  bool supports(PresentationMode mode) {
    switch (mode) {
      case PresentationMode.normal:
        return true;

      case PresentationMode.fullscreen:
        return fullscreen;

      case PresentationMode.pip:
        return pip;

      case PresentationMode.floating:
        return floating;
    }
  }

  /// Fullscreen capability.
  bool get canFullscreen => fullscreen;

  /// PiP capability.
  bool get canPip => pip;

  /// Floating capability.
  bool get canFloating => floating;
}
