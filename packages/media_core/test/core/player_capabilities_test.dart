import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/core/player_capabilities.dart';

void main() {
  group('PlayerCapabilities', () {
    test('basic enables core controls only', () {
      const caps = PlayerCapabilities.basic;
      expect(caps.play, isTrue);
      expect(caps.pause, isTrue);
      expect(caps.seek, isTrue);
      expect(caps.fullscreen, isFalse);
      expect(caps.pictureInPicture, isFalse);
    });

    test('none disables everything', () {
      const caps = PlayerCapabilities.none;
      expect(caps.play, isFalse);
      expect(caps.pause, isFalse);
      expect(caps.setVolume, isFalse);
      expect(caps.stop, isFalse);
    });

    test('full adds extended features', () {
      const caps = PlayerCapabilities.full;
      expect(caps.play, isTrue);
      expect(caps.fullscreen, isTrue);
      expect(caps.pictureInPicture, isTrue);
      expect(caps.backgroundPlayback, isTrue);
      expect(caps.frameStep, isTrue);
      expect(caps.snapshot, isTrue);
    });

    test('copyWith changes selected fields', () {
      const base = PlayerCapabilities.basic;
      final updated = base.copyWith(fullscreen: true, seek: false);
      expect(updated.fullscreen, isTrue);
      expect(updated.seek, isFalse);
      expect(updated.play, isTrue, reason: 'untouched fields keep values');
    });

    test('equality is value based', () {
      expect(PlayerCapabilities.basic, PlayerCapabilities.basic);
      expect(PlayerCapabilities.none, isNot(PlayerCapabilities.basic));
    });
  });
}
