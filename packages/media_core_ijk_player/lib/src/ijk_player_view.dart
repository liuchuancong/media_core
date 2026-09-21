import 'dart:async';
import 'ijk_player_adapter.dart';
import 'package:flutter/material.dart';
import 'package:media_core/media_core.dart';

/// A widget that renders video from an [IjkPlayerAdapter].
///
/// This is a placeholder view that would normally wrap the
/// actual IJK player widget. For this example, it shows
/// a simple container that responds to adapter events.
class IjkPlayerView extends StatefulWidget {
  /// Creates the view.
  const IjkPlayerView({super.key, required this.adapter, this.fit = BoxFit.contain, this.color, this.cover});

  /// The adapter whose underlying player is rendered.
  final IjkPlayerAdapter adapter;

  /// How the video frames are inscribed into the allocated space.
  final BoxFit fit;

  /// Background color behind the video texture.
  final Color? color;

  /// Placeholder widget shown before the first frame is decoded.
  final Widget? cover;

  @override
  State<IjkPlayerView> createState() => _IjkPlayerViewState();
}

class _IjkPlayerViewState extends State<IjkPlayerView> {
  StreamSubscription<PlayerAdapterEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant IjkPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adapter != widget.adapter) {
      _subscription?.cancel();
      _listen();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listen() {
    _subscription = widget.adapter.events.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.adapter.initialized) {
      return widget.cover ?? const SizedBox.expand();
    }

    return Center(
      child: Container(color: widget.color ?? Colors.black, child: widget.cover ?? const SizedBox.expand()),
    );
  }
}
