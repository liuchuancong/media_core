import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_core/source/media_source.dart';
import 'package:media_core/source/media_track.dart';
import 'package:media_core/source/media_track_type.dart';
import 'package:media_core/source/source_headers.dart';

import 'package:media_core_remux/src/android_media_remuxer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('media_core/remux');

  MediaTrack video(String url, {SourceHeaders? headers, Duration? offset}) =>
      MediaTrack(
        uri: Uri.parse(url),
        kind: MediaTrackType.video,
        headers: headers,
        startOffset: offset,
      );

  MediaTrack audio(String url, {SourceHeaders? headers, Duration? offset}) =>
      MediaTrack(
        uri: Uri.parse(url),
        kind: MediaTrackType.audio,
        headers: headers,
        startOffset: offset,
      );

  const defaultReply = '/data/user/0/com.example/cache/remux/out.mp4';

  /// Installs a mock handler and returns the recorded calls.
  ///
  /// [remuxReply] is what the platform answers for `remux` (a path);
  /// [remuxError] installs a failing answer instead.
  List<MethodCall> mockChannel({
    String? remuxReply = defaultReply,
    PlatformException? remuxError,
  }) {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isAvailable') {
        return true;
      }
      if (call.method == 'remux') {
        if (remuxError != null) {
          throw remuxError;
        }
        return remuxReply;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    return calls;
  }

  group('AndroidMediaRemuxer.remux', () {
    test('passes both URLs, merged headers and aligned timeline offsets', () async {
      final headers = SourceHeaders({'Referer': 'https://www.bilibili.com/'});
      final calls = mockChannel();

      final source = CompositeMediaSource(
        videoTracks: [
          video('https://example.com/v.m4s',
              headers: headers, offset: const Duration(milliseconds: 40)),
        ],
        audioTracks: [
          audio(
            'https://example.com/a.m4s',
            headers: headers.set('Cookie', 'SESSDATA=x'),
          ),
        ],
      );

      await AndroidMediaRemuxer().remux(source);

      final call = calls.singleWhere((c) => c.method == 'remux');
      expect(call.arguments['videoUrl'], 'https://example.com/v.m4s');
      expect(call.arguments['audioUrl'], 'https://example.com/a.m4s');

      final sentHeaders = call.arguments['headers'] as Map;
      expect(sentHeaders['Referer'], 'https://www.bilibili.com/');
      expect(sentHeaders['Cookie'], 'SESSDATA=x');

      // Audio (zero offset) anchors the clock; video trails by 40 ms, and
      // it is the *aligned* offsets the muxer needs, not the raw ones.
      expect(call.arguments['audioOffsetUs'], 0);
      expect(call.arguments['videoOffsetUs'], 40000);
    });

    test('returns a progressive file source over the merged MP4', () async {
      mockChannel();

      final source = CompositeMediaSource(
        videoTracks: [video('https://example.com/v.m4s')],
        audioTracks: [audio('https://example.com/a.m4s')],
      );

      final result = await AndroidMediaRemuxer().remux(source);

      expect(result, isA<ProgressiveMediaSource>());
      final track = (result as ProgressiveMediaSource).track;
      expect(track.uri.scheme, 'file');
      expect(track.uri.path, endsWith('out.mp4'));
      expect(track.kind, MediaTrackType.video);
      expect(track.mimeType, 'video/mp4');
      expect(track.metadata['media_core.remuxed'], isTrue);
    });

    test('a composite missing either essence is refused before the platform', () async {
      final calls = mockChannel();

      final videoOnly = CompositeMediaSource(videoTracks: [video('https://example.com/v.m4s')]);
      final audioOnly = CompositeMediaSource(audioTracks: [audio('https://example.com/a.m4s')]);

      await expectLater(
        AndroidMediaRemuxer().remux(videoOnly),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        AndroidMediaRemuxer().remux(audioOnly),
        throwsA(isA<UnsupportedError>()),
      );

      expect(calls.where((c) => c.method == 'remux'), isEmpty);
    });

    test('a null reply from the platform becomes a RemuxFailedError', () async {
      mockChannel(remuxReply: '');

      final source = CompositeMediaSource(
        videoTracks: [video('https://example.com/v.m4s')],
        audioTracks: [audio('https://example.com/a.m4s')],
      );

      await expectLater(
        AndroidMediaRemuxer().remux(source),
        throwsA(isA<RemuxFailedError>()),
      );
    });

    test('a platform failure propagates as PlatformException', () async {
      mockChannel(remuxError: PlatformException(code: 'remux_failed', message: 'mock failure'));

      final source = CompositeMediaSource(
        videoTracks: [video('https://example.com/v.m4s')],
        audioTracks: [audio('https://example.com/a.m4s')],
      );

      await expectLater(
        AndroidMediaRemuxer().remux(source),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('AndroidMediaRemuxer.isAvailable', () {
    test('answers true when the plugin is attached', () async {
      mockChannel();

      expect(await AndroidMediaRemuxer().isAvailable(), isTrue);
    });

    test('answers false when no plugin answers', () async {
      // No mock installed: MissingPluginException path.
      expect(await AndroidMediaRemuxer().isAvailable(), isFalse);
    });
  });
}
