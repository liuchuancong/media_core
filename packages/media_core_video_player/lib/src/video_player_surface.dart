import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart' as vp;
import 'video_player_adapter.dart';

/// A widget that renders video from a [VideoPlayerAdapter].
///
/// Builds the official [VideoPlayer] widget once the adapter
/// has opened a source and the controller is initialized.
///
/// ```dart
/// VideoPlayerSurface(adapter: myAdapter)
/// ```
class VideoPlayerSurface extends StatefulWidget {
  /// Creates the surface.
  const VideoPlayerSurface({
    super.key,
    required this.adapter,
    this.aspectRatio,
  });

  /// The adapter whose controller drives the video output.
  final VideoPlayerAdapter adapter;

  /// Optional fixed aspect ratio; defaults to the native video ratio.
  final double? aspectRatio;

  @override
  State<VideoPlayerSurface> createState() => _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends State<VideoPlayerSurface> {
  @override
  void initState() {
    super.initState();
    widget.adapter.events.listen(_onEvent);
  }

  void _onEvent(_) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.adapter.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }

    final ratio = widget.aspectRatio ?? controller.value.aspectRatio;

    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: vp.VideoPlayer(controller),
      ),
    );
  }
}
