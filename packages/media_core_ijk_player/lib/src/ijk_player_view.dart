import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart';
import 'package:niuma_player/niuma_player.dart' as niuma;

import 'ijk_player_adapter.dart';

/// A widget that renders video from an [IjkPlayerAdapter].
///
/// Builds a niuma_player [NiumaPlayerView] once the adapter has
/// opened a source (niuma constructs its controller together
/// with the source, so there is nothing to render before that).
///
/// ```dart
/// IjkPlayerView(adapter: myAdapter)
/// ```
class IjkPlayerView extends StatefulWidget {
  /// Creates the view.
  const IjkPlayerView({
    super.key,
    required this.adapter,
    this.aspectRatio,
    this.filterQuality,
    this.cover,
  });

  /// The adapter whose controller drives the video output.
  final IjkPlayerAdapter adapter;

  /// Optional fixed aspect ratio; defaults to the video's own.
  final double? aspectRatio;

  /// Texture scaling filter quality (Android native texture path).
  ///
  /// Null uses the niuma default.
  final FilterQuality? filterQuality;

  /// Placeholder shown before a source is opened.
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
    if (!widget.adapter.hasController) {
      return widget.cover ?? const SizedBox.expand();
    }

    final filterQuality = widget.filterQuality;

    if (filterQuality != null) {
      return niuma.NiumaPlayerView(
        widget.adapter.controller,
        aspectRatio: widget.aspectRatio,
        filterQuality: filterQuality,
      );
    }

    return niuma.NiumaPlayerView(widget.adapter.controller, aspectRatio: widget.aspectRatio);
  }
}
