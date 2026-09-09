import 'presentation_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_capabilities.freezed.dart';

/// Describes supported presentation capabilities.
///
/// This model describes what the current platform/environment supports.
///
/// It does not represent the current presentation state.
///
/// Responsibilities:
///
/// - fullscreen availability
/// - picture-in-picture availability
/// - floating window availability
///
/// Non responsibilities:
///
/// - performing transitions
/// - controlling platform APIs
/// - managing UI
@freezed
abstract class PresentationCapabilities with _$PresentationCapabilities {
  const factory PresentationCapabilities({
    /// Whether fullscreen presentation is supported.
    @Default(true) bool fullscreen,

    /// Whether picture-in-picture is supported.
    @Default(false) bool pip,

    /// Whether floating window presentation is supported.
    @Default(false) bool floating,
  }) = _PresentationCapabilities;

  const PresentationCapabilities._();

  /// Creates default capabilities.
  factory PresentationCapabilities.initial() {
    return const PresentationCapabilities(fullscreen: true, pip: false, floating: false);
  }

  /// Whether any advanced presentation mode is available.
  bool get supportsAdvancedPresentation => fullscreen || pip || floating;

  /// Returns whether the given presentation mode is supported.
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

  /// Whether fullscreen is available.
  bool get canFullscreen => fullscreen;

  /// Whether PiP is available.
  bool get canPip => pip;

  /// Whether floating window is available.
  bool get canFloating => floating;
}
