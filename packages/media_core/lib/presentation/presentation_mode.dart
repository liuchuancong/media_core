import 'package:equatable/equatable.dart';

/// Describes how the media presentation is currently displayed.
///
/// Presentation mode is deliberately independent from the underlying media
/// player state. A player can continue playing while its presentation changes
/// from normal to fullscreen, PiP, or floating mode.
///
/// Platform-specific implementations should translate these abstract modes
/// into their corresponding native presentation mechanisms.
enum PresentationMode {
  /// Normal in-page presentation.
  normal,

  /// Fullscreen presentation.
  fullscreen,

  /// Picture-in-picture presentation.
  pip,

  /// Floating presentation above the normal application content.
  floating,
}

/// Immutable value object describing presentation capabilities.
///
/// Capabilities describe what a presentation environment supports; they do
/// not describe the current mode. This distinction allows the controller to
/// reject or avoid unsupported presentation requests without coupling the
/// presentation model to any platform implementation.
final class PresentationCapabilities extends Equatable {
  const PresentationCapabilities({this.fullscreen = true, this.pip = false, this.floating = false});

  /// Whether fullscreen presentation is supported.
  final bool fullscreen;

  /// Whether picture-in-picture presentation is supported.
  final bool pip;

  /// Whether floating presentation is supported.
  final bool floating;

  /// Whether any presentation mode other than normal is supported.
  bool get supportsAdvancedPresentation => fullscreen || pip || floating;

  /// Returns whether [mode] is supported by these capabilities.
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

  /// Creates a copy with selectively replaced capability values.
  PresentationCapabilities copyWith({bool? fullscreen, bool? pip, bool? floating}) {
    return PresentationCapabilities(
      fullscreen: fullscreen ?? this.fullscreen,
      pip: pip ?? this.pip,
      floating: floating ?? this.floating,
    );
  }

  @override
  List<Object?> get props => <Object?>[fullscreen, pip, floating];

  @override
  String toString() {
    return 'PresentationCapabilities('
        'fullscreen: $fullscreen, '
        'pip: $pip, '
        'floating: $floating'
        ')';
  }
}
