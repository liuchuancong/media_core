import 'dart:async';

import 'package:flutter/services.dart';

import 'package:media_core/composition/media_timeline.dart';
import 'package:media_core/remux/media_remuxer.dart';
import 'package:media_core/source/media_source.dart';
import 'package:media_core/source/media_track.dart';
import 'package:media_core/source/media_track_type.dart';

import 'package:media_core_remux/src/remux_failed_error.dart';

export 'package:media_core_remux/src/remux_failed_error.dart';

/// Android implementation of [MediaRemuxer].
///
/// Folds a [CompositeMediaSource]'s separated video and audio essences
/// into one interleaved MP4 in the app cache directory using the
/// platform's own `MediaExtractor` + `MediaMuxer` stack, then returns a
/// [ProgressiveMediaSource] pointing at the local file. This is the
/// "Android Remuxer" leg of the pipeline: a Fijk-class backend that
/// declares [CompositeSupport.none] can play the merged file as if it
/// had been a single progressive stream all along, and the planner's
/// [RemuxPlan] loop in `PlayerKernel.createFromMedia` runs it with no
/// further wiring.
///
/// What the merge honors:
///
/// - **Request headers** (Referer / User-Agent / Cookie) are applied to
///   both essence URLs, which is what lets Bilibili's gated
///   `video.m4s` / `audio.m4s` be read at all.
/// - **Per-track presentation alignment** from [MediaTimeline]: each
///   essence's aligned offset is added to its sample timestamps before
///   muxing, so a DASH audio period that trails the video by tens of
///   milliseconds stays in sync inside the merged file instead of
///   drift-cut at its own zero.
///
/// What the merge does not do:
///
/// - Subtitle tracks are dropped. MP4 subtitle muxing (tx3g/CMFC) is
///   out of the platform muxer's practical scope, and a subtitle that
///   matters belongs on a backend that selects it natively.
/// - No re-encode: samples are copied, so the codec strings survive
///   unchanged (an HEVC pair stays HEVC; whether the target single-URL
///   backend can decode it is that backend's declared business).
///
/// Availability: the channel only answers on Android. Call [isAvailable]
/// before installing this as the kernel's `remuxer:` on a build that
/// may run elsewhere — or simply skip construction off Android, since
/// every method otherwise throws [PlatformException]-free errors
/// (`MissingPluginException`) that the kernel turns into a clear
/// [UnsupportedError] on the second remux refusal.
final class AndroidMediaRemuxer implements MediaRemuxer {
  /// Creates a remuxer bound to [channel].
  ///
  /// The channel defaults to the one the Android plugin registers;
  /// tests pass a mock.
  AndroidMediaRemuxer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  /// Method channel name, kept in sync with `MediaRemuxPlugin.java`.
  static const String _channelName = 'media_core/remux';

  final MethodChannel _channel;

  /// Whether the Android platform plugin answers on this build.
  ///
  /// Used by app startup to decide between installing the remuxer and
  /// leaving composite-on-none sources to the planner's explicit
  /// [UnsupportedPlan] instead of a runtime muxing failure.
  Future<bool> isAvailable() async {
    try {
      final answer = await _channel.invokeMethod<bool>('isAvailable');
      return answer ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Remuxes [source]'s primary video and primary audio into one MP4.
  ///
  /// Returns a [ProgressiveMediaSource] over the local file; the
  /// kernel's [RemuxPlan] loop feeds it back through the planner,
  /// where it becomes a [DirectPlan] the single-URL backend accepts.
  ///
  /// Throws [UnsupportedError] when the composite is missing either
  /// essence (a muxer cannot invent one), and [RemuxFailedError] when
  /// the platform reports a failure.
  @override
  Future<MediaSource> remux(CompositeMediaSource source) async {
    final video = source.primaryVideo;
    final audio = source.primaryAudio;
    if (video == null || audio == null) {
      throw UnsupportedError(
        'AndroidMediaRemuxer needs one video and one audio essence; '
        'this composite has ${video == null ? 'no video' : 'no audio'}.',
      );
    }

    final timeline = MediaTimeline.from(source);
    final headers = _mergedHeaders(video, audio);

    final path = await _channel.invokeMethod<String>('remux', <String, Object?>{
      'videoUrl': video.uri.toString(),
      'audioUrl': audio.uri.toString(),
      'headers': headers,
      'videoOffsetUs': timeline[video]?.offset.inMicroseconds ?? 0,
      'audioOffsetUs': timeline[audio]?.offset.inMicroseconds ?? 0,
    });

    if (path == null || path.isEmpty) {
      throw RemuxFailedError('Android remuxer returned no output path.');
    }

    return ProgressiveMediaSource(
      track: MediaTrack(
        uri: Uri.file(path),
        kind: MediaTrackType.video,
        mimeType: 'video/mp4',
        metadata: const <String, Object?>{
          'media_core.remuxed': true,
        },
      ),
    );
  }

  Map<String, String> _mergedHeaders(MediaTrack video, MediaTrack audio) {
    final audioHeaders = audio.headers;
    var merged = video.headers;
    if (merged == null) {
      merged = audioHeaders;
    } else if (audioHeaders != null && audioHeaders.isNotEmpty) {
      merged = merged.merge(audioHeaders);
    }
    return merged?.toMap() ?? const <String, String>{};
  }
}
