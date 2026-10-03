import 'package:flutter_test/flutter_test.dart';

import 'package:flame_barrage/flame_barrage.dart';

import 'package:media_core_danmaku/media_core_danmaku.dart';

void main() {
  group('DanmakuOverlayConfig.toBarrageConfig', () {
    test('the rendering knobs land on their engine counterparts', () {
      const config = DanmakuOverlayConfig(
        maxMessages: 8,
        fps: 24,
        fontSize: 12,
        opacity: 0.5,
        displayAreaFraction: 0.4,
        showStroke: false,
        strokeWidth: 2,
      );

      final engine = config.toBarrageConfig();

      expect(engine.maxVisibleCount, 8);
      expect(engine.fps, 24);
      expect(engine.fontSize, 12);
      expect(engine.opacity, 0.5);
      expect(engine.area, 0.4);
      expect(engine.showStroke, isFalse);
      expect(engine.strokeWidth, 2);
    });

    test('a relative speed needs the reference the engine cannot know', () {
      // The overlay's speed is a multiplier and the engine's is pixels per
      // second, so the mapping is only honest with the reference supplied.
      const config = DanmakuOverlayConfig(speedMultiplier: 0.5);

      expect(config.toBarrageConfig(baseSpeed: 200).baseSpeed, 100);
      expect(config.toBarrageConfig().baseSpeed, 60);
    });

    test('defaults produce a usable engine config', () {
      final engine = DanmakuOverlayConfig.defaults.toBarrageConfig();

      expect(engine, isA<BarrageConfig>());
      expect(engine.maxVisibleCount, DanmakuOverlayConfig.defaults.maxMessages);
      expect(engine.baseSpeed, greaterThan(0));
    });
  });
}
