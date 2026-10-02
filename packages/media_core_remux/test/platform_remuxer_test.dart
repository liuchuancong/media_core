import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:media_core/media_core.dart';

import 'package:media_core_remux/src/ffmpeg_media_remuxer.dart';

void main() {
  group('platformRemuxer', () {
    test('answers with the FFmpeg leg on a platform that has an FFmpeg', () {
      if (!remuxSupported) {
        return; // Web or an unsupported host; the null path below covers it.
      }

      expect(platformRemuxer(), isA<FfmpegMediaRemuxer>());
    });

    test('the supported flag agrees with the factory', () {
      final supported = Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows ||
          Platform.isLinux;

      expect(remuxSupported, isTrue, reason: 'tests run on a desktop host');
      expect(supported, isTrue);
      expect(platformRemuxer(), isA<MediaRemuxer>());
    });

    test('the caller runner seam reaches the produced remuxer', () async {
      final seen = <List<String>>[];
      final remuxer = platformRemuxer(
        ffmpegRun: (args) async {
          seen.add(args);
          return 0;
        },
      )!;

      await remuxer.remux(
        CompositeMediaSource(
          videoTracks: [
            MediaTrack(
              uri: Uri.parse('https://example.com/v.m4s'),
              kind: MediaTrackType.video,
            ),
          ],
          audioTracks: [
            MediaTrack(
              uri: Uri.parse('https://example.com/a.m4s'),
              kind: MediaTrackType.audio,
            ),
          ],
        ),
      );

      expect(seen.single, contains('-i'));
    });
  });
}
