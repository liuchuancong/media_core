import 'package:equatable/equatable.dart';

/// Describes presentation capabilities.
///
/// Capability represents what the current platform adapter supports.
///
/// It does not describe current presentation state.
/// Current state is represented by PresentationState.
final class PresentationCapability extends Equatable {
  /// Creates presentation capabilities.
  const PresentationCapability({this.fullscreen = true, this.pip = false, this.floating = false});

  /// Whether fullscreen is supported.
  final bool fullscreen;

  /// Whether picture-in-picture is supported.
  final bool pip;

  /// Whether floating window is supported.
  final bool floating;

  /// Whether any presentation mode is available.
  bool get any => fullscreen || pip || floating;

  /// Whether no presentation mode is supported.
  bool get none => !any;

  /// Creates a copy with changed values.
  PresentationCapability copyWith({bool? fullscreen, bool? pip, bool? floating}) {
    return PresentationCapability(
      fullscreen: fullscreen ?? this.fullscreen,
      pip: pip ?? this.pip,
      floating: floating ?? this.floating,
    );
  }

  @override
  List<Object?> get props => <Object?>[fullscreen, pip, floating];

  @override
  String toString() {
    return 'PresentationCapability('
        'fullscreen: $fullscreen, '
        'pip: $pip, '
        'floating: $floating'
        ')';
  }
}
