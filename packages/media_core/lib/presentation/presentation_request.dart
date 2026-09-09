import 'presentation_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_request.freezed.dart';

/// Describes a requested presentation transition.
///
/// A request only represents an intention.
///
/// It does not perform any platform operation.
///
/// Actual transition is handled by:
///
/// - PresentationController
/// - FullscreenController
/// - PipController
/// - FloatingController
///
/// Platform adapters are responsible for applying
/// native presentation behavior.
@freezed
abstract class PresentationRequest with _$PresentationRequest {
  const factory PresentationRequest({
    /// Target presentation mode.
    @Default(PresentationMode.normal) PresentationMode mode,

    /// Whether transition should be animated.
    @Default(true) bool animated,

    /// Whether request was triggered automatically.
    ///
    /// Examples:
    ///
    /// - orientation changed
    /// - playback state changed
    /// - app lifecycle event
    @Default(false) bool automatic,

    /// Optional request source.
    ///
    /// Examples:
    ///
    /// - user
    /// - orientation
    /// - lifecycle
    /// - system
    String? source,
  }) = _PresentationRequest;

  const PresentationRequest._();

  /// Creates normal mode request.
  factory PresentationRequest.normal({bool animated = true, String? source}) {
    return PresentationRequest(mode: PresentationMode.normal, animated: animated, source: source);
  }

  /// Creates fullscreen request.
  factory PresentationRequest.fullscreen({bool animated = true, bool automatic = false, String? source}) {
    return PresentationRequest(
      mode: PresentationMode.fullscreen,
      animated: animated,
      automatic: automatic,
      source: source,
    );
  }

  /// Creates PiP request.
  factory PresentationRequest.pip({bool animated = true, String? source}) {
    return PresentationRequest(mode: PresentationMode.pip, animated: animated, source: source);
  }

  /// Creates floating window request.
  factory PresentationRequest.floating({bool animated = true, String? source}) {
    return PresentationRequest(mode: PresentationMode.floating, animated: animated, source: source);
  }

  /// Whether this enters fullscreen.
  bool get isFullscreen => mode == PresentationMode.fullscreen;

  /// Whether this enters PiP.
  bool get isPip => mode == PresentationMode.pip;

  /// Whether this enters floating mode.
  bool get isFloating => mode == PresentationMode.floating;

  /// Whether this restores normal mode.
  bool get isNormal => mode == PresentationMode.normal;
}
