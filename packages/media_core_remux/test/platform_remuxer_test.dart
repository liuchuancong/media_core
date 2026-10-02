import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:media_core/remux/media_remuxer.dart';

import 'package:media_core_remux/src/android_media_remuxer.dart';
import 'package:media_core_remux/src/ffmpeg_media_remuxer.dart';

void main() {
  group('platformRemuxer', () {
    test('ffmpeg preference answers on every platform, Android included', () async {
      final remuxer = await platformRemuxer(
        preference: PlatformRemuxerPreference.ffmpeg,
      );

      expect(remuxer, isA<FfmpegMediaRemuxer>());
    });

    test('auto prefers FFmpeg off Android', () async {
      if (Platform.isAndroid) {
        return; // Native leg owns this branch; exercised on device.
      }

      final remuxer = await platformRemuxer();

      expect(remuxer, isA<FfmpegMediaRemuxer>());
    });

    test('androidNative never exists off Android', () async {
      if (Platform.isAndroid) {
        return; // The attached-plugin answer is device-only behavior.
      }

      expect(
        await platformRemuxer(
          preference: PlatformRemuxerPreference.androidNative,
        ),
        isNull,
      );
    });

    test('a chosen remuxer is usable as the MediaRemuxer contract', () async {
      final remuxer = await platformRemuxer(
        preference: PlatformRemuxerPreference.ffmpeg,
      );

      expect(remuxer, isA<MediaRemuxer>());
      // The factory hands back the caller's runner seam untouched —
      // proof the instance is the configured one, not a re-defaulted copy.
      final runnerArguments = <List<String>>[];
      final configured = await platformRemuxer(
        preference: PlatformRemuxerPreference.ffmpeg,
        ffmpegRun: (args) async {
          runnerArguments.add(args);
          return 0;
        },
      );
      expect(configured, isA<FfmpegMediaRemuxer>());
      expect(remuxer, isNot(same(configured)));
    });

    test('AndroidMediaRemuxer remains directly constructible for explicit wiring', () {
      // A host on Android that wants the native leg without the
      // availability probe (it knows its own build) constructs it
      // directly; the factory is convenience, not the only door.
      expect(AndroidMediaRemuxer(), isA<MediaRemuxer>());
    });
  });
}
