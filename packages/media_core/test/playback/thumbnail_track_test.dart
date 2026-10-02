import 'package:flutter_test/flutter_test.dart';

import 'package:media_core/playback/thumbnail_slice.dart';
import 'package:media_core/playback/thumbnail_track.dart';

const _spriteVtt = '''
WEBVTT
Kind: thumbnails
Hyphenated: true

00:00:00.000 --> 00:00:10.000
thumbs.jpg#xywh=0,0,160,90

00:00:10.000 --> 00:00:20.000
thumbs.jpg#xywh=160,0,160,90

00:01:50.000 --> 00:02:00.000
thumbs.jpg#xywh=0,90,160,90
''';

void main() {
  group('ThumbnailSlice.tryParse', () {
    test('parses four integers', () {
      final slice = ThumbnailSlice.tryParse('160,0,160,90');

      expect(slice, const ThumbnailSlice(x: 160, y: 0, width: 160, height: 90));
    });

    test('rejects shapes the thumbnail profile does not use', () {
      expect(ThumbnailSlice.tryParse('10,20,30'), isNull);
      expect(ThumbnailSlice.tryParse('a,b,c,d'), isNull);
      expect(ThumbnailSlice.tryParse('10%,20%,30,40'), isNull);
    });
  });

  group('ThumbnailTrack.parseWebVtt', () {
    test('parses sprite cues and drops the fragment from the url', () {
      final track = ThumbnailTrack.parseWebVtt(_spriteVtt);

      expect(track.thumbnails, hasLength(3));
      expect(track.cueInterval, const Duration(seconds: 10));

      final second = track.thumbnails[1];
      expect(second.imageUrl.toString(), 'thumbs.jpg');
      expect(second.slice, const ThumbnailSlice(x: 160, y: 0, width: 160, height: 90));
      expect(second.start, const Duration(seconds: 10));
      expect(second.end, const Duration(seconds: 20));
    });

    test('at resolves the cue under a hovered time', () {
      final track = ThumbnailTrack.parseWebVtt(_spriteVtt);

      expect(track.at(const Duration(seconds: 5))!.slice!.x, 0);
      expect(track.at(const Duration(seconds: 15))!.slice!.x, 160);
      expect(track.at(const Duration(seconds: 115))!.slice!.y, 90);
    });

    test('cues are end-exclusive and out-of-range answers null', () {
      final track = ThumbnailTrack.parseWebVtt(_spriteVtt);

      expect(track.at(const Duration(seconds: 10))!.slice!.x, 160);
      expect(track.at(const Duration(minutes: 5)), isNull);
      expect(track.at(const Duration(seconds: 120)), isNull);
    });

    test('a caption VTT parses to an empty track, not an error', () {
      const captions = '''
WEBVTT

00:00:01.000 --> 00:00:04.000
Hello there, how are you?

00:00:05.000 --> 00:00:08.000
I am fine, thanks.
''';

      final track = ThumbnailTrack.parseWebVtt(captions);

      expect(track.isEmpty, isTrue);
      expect(track.at(const Duration(seconds: 2)), isNull);
    });

    test('a malformed timing line drops only its own cue', () {
      const broken = '''
WEBVTT

00:00:00.000 --> not-a-time
thumbs.jpg#xywh=0,0,80,45

00:00:10.000 --> 00:00:20.000
thumbs.jpg#xywh=80,0,80,45
''';

      final track = ThumbnailTrack.parseWebVtt(broken);

      expect(track.thumbnails, hasLength(1));
      expect(track.thumbnails.single.slice, const ThumbnailSlice(x: 80, y: 0, width: 80, height: 45));
    });

    test('hour-less timestamps and settings suffixes parse', () {
      const short = '''
WEBVTT

00:10.000 --> 00:20.000 line:0% align:start
t.jpg#xywh=0,0,64,36
''';

      final track = ThumbnailTrack.parseWebVtt(short);

      expect(track.thumbnails.single.start, const Duration(seconds: 10));
      expect(track.thumbnails.single.end, const Duration(seconds: 20));
    });

    test('standalone image cues without a fragment keep the full url', () {
      const plain = '''
WEBVTT

00:00:00.000 --> 00:00:10.000
https://cdn.example.com/frames/f1.jpg
''';

      final track = ThumbnailTrack.parseWebVtt(plain);

      expect(track.thumbnails.single.imageUrl.toString(), 'https://cdn.example.com/frames/f1.jpg');
      expect(track.thumbnails.single.slice, isNull);
    });
  });
}
