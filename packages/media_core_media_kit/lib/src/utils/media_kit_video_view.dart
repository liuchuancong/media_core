import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:media_core_media_kit/media_core_media_kit.dart';

/// A widget that renders video from a [MediaKitPlayerAdapter].
///
/// Uses the adapter's own [VideoController] — the adapter is the single
/// owner of the mpv surface, so this widget never creates a second one.
///
/// ```dart
/// MediaKitVideoView(adapter: myAdapter)
/// ```
class MediaKitVideoView extends StatelessWidget {
  const MediaKitVideoView({
    super.key,
    required this.adapter,
    this.fit = BoxFit.contain,
    this.controls,
    this.width,
    this.height,
  });

  /// The adapter whose underlying player is rendered.
  final MediaKitPlayerAdapter adapter;

  /// How the video frames are inscribed into the allocated space.
  final BoxFit fit;

  /// Optional controls builder passed to the underlying [mkv.Video].
  ///
  /// When null, [mkv.NoVideoControls] is used.
  final mkv.VideoControlsBuilder? controls;

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final controller = adapter.videoController;
    if (controller == null) return const SizedBox.expand();

    return mkv.Video(
      controller: controller,
      controls: controls ?? mkv.NoVideoControls,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
