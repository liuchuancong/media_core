import 'package:built_value/built_value.dart';
import 'package:media_core/src/screenshot/screenshot_format.dart' show ScreenshotFormat;

part 'screenshot_request.g.dart';

/// Frame-capture request handed to a backend adapter.
///
/// It carries only what an engine needs to produce an image. PlayerIdentity identity,
/// playback position and frame size are attached by the kernel when the bytes
/// come back, because the engine knows nothing about the surrounding player —
/// and because a captured frame is worth keeping even if the player is torn
/// down immediately afterwards.
///
/// Responsibilities:
///
/// - describe the wanted encoding
///
/// It does not:
///
/// - identify the player
/// - carry the resulting bytes
/// - decide which route is used
///
/// Those belong to:
///
/// - PlayerAdapter.captureFrame
/// - PlayerScreenshot
/// - ScreenshotManager
abstract class ScreenshotRequest implements Built<ScreenshotRequest, ScreenshotRequestBuilder> {
  /// Builds ScreenshotRequest from a [updates] callback — the codegen entry.
  factory ScreenshotRequest([void Function(ScreenshotRequestBuilder)? updates]) = _$ScreenshotRequest;

  /// Creates a capture request.
  factory ScreenshotRequest.of({
    required ScreenshotFormat format,
    int quality = 90,
    bool includeSubtitles = false,
  }) {
    return ScreenshotRequest(
      (builder) => builder
        ..format = format
        ..quality = quality
        ..includeSubtitles = includeSubtitles,
    );
  }

  ScreenshotRequest._();

  /// A request nobody qualified wants a medium-quality JPEG without subtitles.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(ScreenshotRequestBuilder builder) => builder
    ..quality = 90
    ..includeSubtitles = false;

  /// Requested image format.
  ///
  /// An implementation that cannot encode it must return null rather than
  /// mislabel bytes: the caller falls back to a surface capture, which does
  /// produce a different format and says so.
  ScreenshotFormat get format;

  /// JPEG quality in the 1–100 range; ignored for PNG.
  int get quality;

  /// Whether subtitles rendered by the engine should be included.
  bool get includeSubtitles;

  /// [format] as the MIME string engines are given.
  String get mimeType => format.mimeType;

  /// [quality] clamped to the range engines accept.
  int get effectiveQuality => quality.clamp(1, 100);

  /// Whether this request asks for a lossy encoding.
  bool get isLossy => format.isLossy;
}
