import 'presentation_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_capabilities.freezed.dart';

/// Describes supported presentation capabilities.
///
/// Capability describes what the current platform supports.
///
/// It does not represent current presentation state.
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
    /// Fullscreen support.
    @Default(true) bool fullscreen,

    /// Picture-in-picture support.
    @Default(false) bool pip,

    /// Floating window support.
    @Default(false) bool floating,
  }) = _PresentationCapabilities;

  const PresentationCapabilities._();

  /// Default capability.
  factory PresentationCapabilities.initial() {
    return const PresentationCapabilities(fullscreen: true, pip: false, floating: false);
  }

  /// Whether any presentation mode is supported.
  bool get any => fullscreen || pip || floating;

  /// Whether no presentation mode is supported.
  bool get none => !any;

  /// Whether fullscreen is supported.
  bool get canFullscreen => fullscreen;

  /// Whether PiP is supported.
  bool get canPip => pip;

  /// Whether floating is supported.
  bool get canFloating => floating;

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

  /// Supported modes.
  List<PresentationMode> get supportedModes {
    return [
      if (fullscreen) PresentationMode.fullscreen,

      if (pip) PresentationMode.pip,

      if (floating) PresentationMode.floating,
    ];
  }
}
