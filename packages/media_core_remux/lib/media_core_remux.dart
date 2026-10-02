/// Remux services for media_core.
///
/// Folds a [CompositeMediaSource]'s separated essences into one
/// playable file so `CompositeSupport.none` backends can play DASH
/// pairs, closing the planner's [RemuxPlan] branch:
///
/// - [FfmpegMediaRemuxer] — the one stream-copy leg, on every platform
///   `ffmpeg_kit_extended_flutter` runs on;
/// - [platformRemuxer] / [remuxSupported] — the same answer for the
///   current platform, and null where there is no FFmpeg to drive.
library;

export 'package:media_core_remux/src/ffmpeg_media_remuxer.dart';
export 'package:media_core_remux/src/remux_failed_error.dart';
