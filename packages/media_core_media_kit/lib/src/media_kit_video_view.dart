import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'media_kit_player_adapter.dart';

/// A widget that renders video from a [MediaKitPlayerAdapter].
///
/// Creates a media_kit [VideoController] internally and drives
/// a [Video] widget. The controller is disposed when the widget
/// is removed from the tree.
///
/// ```dart
/// MediaKitVideoView(adapter: myAdapter)
/// ```
class MediaKitVideoView extends StatefulWidget {
  /// Creates the view.
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

  /// Optional video controls builder passed to the underlying [Video] widget.
  ///
  /// When null the default (no controls) is used.
  final mkv.VideoControlsBuilder? controls;

  /// Optional fixed width for the video texture.
  final double? width;

  /// Optional fixed height for the video texture.
  final double? height;

  @override
  State<MediaKitVideoView> createState() => _MediaKitVideoViewState();
}

class _MediaKitVideoViewState extends State<MediaKitVideoView> {
  mkv.VideoController? _controller;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(covariant MediaKitVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adapter != widget.adapter) {
      _controller = null;
      _attachController();
    }
  }

  @override
  void dispose() {
    // VideoController is disposed by the underlying Player.
    _controller = null;
    super.dispose();
  }

  void _attachController() {
    if (!widget.adapter.initialized) return;
    _controller = mkv.VideoController(
      widget.adapter.player,
      configuration: const mkv.VideoControllerConfiguration(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !widget.adapter.initialized) {
      return const SizedBox.expand();
    }

    return mkv.Video(
      controller: controller,
      controls: widget.controls,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }
}
