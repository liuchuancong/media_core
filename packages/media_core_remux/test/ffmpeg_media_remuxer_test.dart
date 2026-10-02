import 'package:flutter_test/flutter_test.dart';

import 'package:media_core/source/media_source.dart';
import 'package:media_core/source/media_track.dart';
import 'package:media_core/source/media_track_type.dart';
import 'package:media_core/source/source_headers.dart';

import 'package:media_core_remux/src/ffmpeg_media_remuxer.dart';
import 'package:media_core_remux/src/remux_failed_error.dart';

MediaTrack _video(String url, {SourceHeaders? headers, Duration? offset}) {
  return MediaTrack(
    uri: Uri.parse(url),
    kind: MediaTrackType.video,
    headers: headers,
    startOffset: offset,
  );
}

MediaTrack _audio(String url, {SourceHeaders? headers, Duration? offset}) {
  return MediaTrack(
    uri: Uri.parse(url),
    kind: MediaTrackType.audio,
    headers: headers,
    startOffset: offset,
  );
}

CompositeMediaSource _pair({
  SourceHeaders? headers,
  Duration videoOffset = Duration.zero,
  Duration audioOffset = Duration.zero,
}) {
  return CompositeMediaSource(
    videoTracks: [
      _video('https://example.com/v.m4s', headers: headers, offset: videoOffset),
    ],
    audioTracks: [
      _audio('https://example.com/a.m4s', headers: headers, offset: audioOffset),
    ],
  );
}

void main() {
  group('FfmpegMediaRemuxer.argumentsFor', () {
    test('copies both essences with explicit maps', () {
      final args = FfmpegMediaRemuxer.argumentsFor(
        _pair(),
        outputPath: '/tmp/out.mp4',
      );

      expect(args, containsAllInOrder(['-map', '0:v:0', '-map', '1:a:0']));
      expect(args, containsAllInOrder(['-c', 'copy']));
      expect(args.last, '/tmp/out.mp4');
      expect(args, containsAllInOrder(['-i', 'https://example.com/v.m4s']));
      expect(args, containsAllInOrder(['-i', 'https://example.com/a.m4s']));
    });

    test('per-input headers precede their own -i', () {
      final args = FfmpegMediaRemuxer.argumentsFor(
        _pair(
          headers: SourceHeaders({
            'User-Agent': 'test-agent',
            'Referer': 'https://www.bilibili.com/',
          }),
        ),
        outputPath: '/tmp/out.mp4',
      );

      final videoIndex = args.indexOf('https://example.com/v.m4s');
      final uaIndex = args.indexOf('test-agent') - 1;
      final headersIndex = args.indexWhere((a) => a == '-headers');

      expect(uaIndex, lessThan(videoIndex));
      expect(headersIndex, lessThan(videoIndex));
      // User-Agent travels as -user_agent, never duplicated in -headers.
      expect(args[headersIndex + 1], isNot(contains('User-Agent')));
      expect(args[headersIndex + 1], contains('Referer'));
    });

    test('aligned timeline offsets become per-input -itsoffset', () {
      final args = FfmpegMediaRemuxer.argumentsFor(
        _pair(audioOffset: const Duration(milliseconds: 20)),
        outputPath: '/tmp/out.mp4',
      );

      // Audio anchors the clock; the video trails by 20 ms, so the
      // second input carries the offset immediately before its -i.
      final audioIndex = args.indexOf('https://example.com/a.m4s');
      expect(args[audioIndex - 1], '-i');
      expect(args[audioIndex - 2], '0.020');
      expect(args[audioIndex - 3], '-itsoffset');
      // Exactly one offset: the video, sitting at the origin, needs none.
      expect(args.where((a) => a == '-itsoffset'), hasLength(1));
    });

    test('values containing CR or LF are dropped from -headers', () {
      final args = FfmpegMediaRemuxer.argumentsFor(
        CompositeMediaSource(
          videoTracks: [
            _video('https://example.com/v.m4s',
                headers: SourceHeaders({'X-Evil': 'a\r\nInjected: yes'})),
          ],
          audioTracks: [_audio('https://example.com/a.m4s')],
        ),
        outputPath: '/tmp/out.mp4',
      );

      final headersIndex = args.indexOf('-headers');
      expect(headersIndex, -1, reason: 'no smuggled line may reach the builder');
    });
  });

  group('FfmpegMediaRemuxer.remux', () {
    test('exit code 0 produces a progressive file source', () async {
      final seen = <List<String>>[];
      final remuxer = FfmpegMediaRemuxer(
        run: (args) async {
          seen.add(args);
          return 0;
        },
        outputDirectory: () async => '/tmp/remux-test',
      );

      final result = await remuxer.remux(_pair());

      expect(result, isA<ProgressiveMediaSource>());
      final track = (result as ProgressiveMediaSource).track;
      expect(track.uri.scheme, 'file');
      expect(track.uri.path, endsWith('.mp4'));
      expect(track.metadata['media_core.remuxer'], 'ffmpeg');
      expect(seen.single.last, track.uri.toFilePath());
    });

    test('a non-zero exit becomes RemuxFailedError', () async {
      final remuxer = FfmpegMediaRemuxer(
        run: (_) async => 1,
        outputDirectory: () async => '/tmp/remux-test',
      );

      await expectLater(
        remuxer.remux(_pair()),
        throwsA(isA<RemuxFailedError>()),
      );
    });

    test('a composite missing an essence is refused before FFmpeg runs', () async {
      var runs = 0;
      final remuxer = FfmpegMediaRemuxer(
        run: (_) async {
          runs++;
          return 0;
        },
        outputDirectory: () async => '/tmp/remux-test',
      );

      await expectLater(
        remuxer.remux(
          CompositeMediaSource(videoTracks: [_video('https://example.com/v.m4s')]),
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(runs, 0);
    });
  });
}
