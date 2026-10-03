import 'package:flutter_test/flutter_test.dart';

import 'package:media_core/quality/quality_candidate.dart';
import 'package:media_core/source/media_source.dart';
import 'package:media_core/source/media_track.dart';
import 'package:media_core/source/media_track_type.dart';

MediaTrack _track(String url, MediaTrackType kind, {int? bitrate}) {
  return MediaTrack(uri: Uri.parse(url), kind: kind, bitrate: bitrate);
}

void main() {
  group('QualityCandidate.fromCompositeTracks', () {
    test('one candidate per video track, each keeping the shared audio', () {
      final candidates = QualityCandidate.fromCompositeTracks(
        [
          _track('https://example.com/720.m4s', MediaTrackType.video, bitrate: 2000),
          _track('https://example.com/1080.m4s', MediaTrackType.video, bitrate: 4000),
        ],
        audioTracks: [_track('https://example.com/a.m4s', MediaTrackType.audio)],
      );

      expect(candidates, hasLength(2));
      expect(candidates.last.bitrate, 4000);
      for (final candidate in candidates) {
        final source = candidate.source as CompositeMediaSource;
        expect(source.videoTracks, hasLength(1));
        expect(source.audioTracks, hasLength(1));
      }
    });

    test('carries subtitles and the live declaration into every candidate', () {
      // A quality switch that dropped these would play the same picture
      // with no captions, and would reclassify a broadcast as on-demand —
      // turning off every downstream `isLive` guard on the new source.
      final candidates = QualityCandidate.fromCompositeTracks(
        [_track('https://example.com/720.m4s', MediaTrackType.video)],
        audioTracks: [_track('https://example.com/a.m4s', MediaTrackType.audio)],
        subtitleTracks: [_track('https://example.com/s.vtt', MediaTrackType.subtitle)],
        live: true,
      );

      final source = candidates.single.source as CompositeMediaSource;

      expect(source.subtitleTracks, hasLength(1));
      expect(source.live, isTrue);
    });
  });
}
