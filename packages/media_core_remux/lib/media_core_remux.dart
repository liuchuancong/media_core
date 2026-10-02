/// Remux services for media_core.
///
/// Folds a [CompositeMediaSource]'s separated essences into one
/// playable file so `CompositeSupport.none` backends can play DASH
/// pairs, closing the planner's [RemuxPlan] branch:
///
/// - [AndroidMediaRemuxer] — the platform MediaExtractor/MediaMuxer
///   leg (Android, lightest);
/// - [FfmpegMediaRemuxer] — the cross-platform stream-copy leg
///   (iOS / macOS / Windows / Linux via `ffmpeg_kit_extended_flutter`);
/// - [platformRemuxer] — the capability-first selection between them.
library;

export 'package:media_core_remux/src/android_media_remuxer.dart';
export 'package:media_core_remux/src/ffmpeg_media_remuxer.dart';
export 'package:media_core_remux/src/remux_failed_error.dart';
