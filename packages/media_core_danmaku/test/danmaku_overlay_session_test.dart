import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';

DanmakuMessage chat(String text, {DanmakuStyle? style}) {
  return DanmakuMessage(type: DanmakuMessageType.chat, userName: 'viewer', text: text, style: style);
}

final class _RecordingSink implements DanmakuSink {
  final List<String> messages = <String>[];
  final List<String> notices = <String>[];
  int clearCount = 0;

  @override
  void onDanmaku(DanmakuMessage message, {bool immediate = false}) => messages.add(message.text);

  @override
  void onAudienceUpdate(DanmakuAudienceUpdate update) {}

  @override
  void onSuperChat(DanmakuSuperChat message) {}

  @override
  void onNotice(DanmakuNotice notice) => notices.add(notice.name);

  @override
  void onTransportNotice(String message) {}

  @override
  void onRoomChanged(String? roomId) {}

  @override
  void clearRendered() => clearCount++;
}

void main() {
  group('DanmakuOverlaySession queue', () {
    test('refuses messages until the surface is visible', () async {
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);

      expect(overlay.isActive, isFalse);
      expect(overlay.enqueue(chat('hello')), isFalse);
      expect(overlay.length, 0);

      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);

      expect(overlay.isActive, isTrue);
      expect(overlay.enqueue(chat('hello')), isTrue);
      expect(overlay.length, 1);
    });

    test('empties itself when the surface goes away', () async {
      final visibility = StreamController<bool>.broadcast();
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      addTearDown(visibility.close);
      overlay.bindVisibility(visibility.stream);

      visibility.add(true);
      await Future<void>.delayed(Duration.zero);
      overlay.enqueue(chat('one'));
      overlay.enqueue(chat('two'));
      expect(overlay.length, 2);

      visibility.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(overlay.length, 0, reason: 'a hidden window must not replay a backlog when it returns');
      expect(overlay.isActive, isFalse);
    });

    test('keeps the queue when clearOnHide is off', () async {
      final visibility = StreamController<bool>.broadcast();
      final overlay = DanmakuOverlaySession(
        config: DanmakuOverlayConfig.defaults.copyWith(clearOnHide: false),
      );
      addTearDown(overlay.dispose);
      addTearDown(visibility.close);
      overlay.bindVisibility(visibility.stream);

      visibility.add(true);
      await Future<void>.delayed(Duration.zero);
      overlay.enqueue(chat('kept'));

      visibility.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(overlay.length, 1);
      expect(overlay.isActive, isFalse, reason: 'still refusing new messages while hidden');
    });

    test('drops the oldest message when the queue is full', () async {
      final overlay = DanmakuOverlaySession(config: DanmakuOverlayConfig.defaults.copyWith(maxMessages: 2));
      addTearDown(overlay.dispose);
      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);

      overlay.enqueue(chat('first'));
      overlay.enqueue(chat('second'));
      overlay.enqueue(chat('third'));

      expect(overlay.items.map((item) => item.message.text).toList(), <String>['second', 'third']);
    });

    test('a disabled overlay refuses and holds nothing', () async {
      final overlay = DanmakuOverlaySession(config: DanmakuOverlayConfig.defaults.copyWith(enabled: false));
      addTearDown(overlay.dispose);
      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);

      expect(overlay.enqueue(chat('hello')), isFalse);
      expect(overlay.isActive, isFalse);
    });

    test('disabling an active overlay empties it', () async {
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);
      overlay.enqueue(chat('hello'));

      overlay.updateConfig(DanmakuOverlayConfig.defaults.copyWith(enabled: false));

      expect(overlay.length, 0);
    });

    test('shrinking the bound trims immediately', () async {
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);
      for (var index = 0; index < 5; index++) {
        overlay.enqueue(chat('message $index'));
      }

      overlay.updateConfig(DanmakuOverlayConfig.defaults.copyWith(maxMessages: 2));

      expect(overlay.length, 2);
    });

    test('empty text is refused', () async {
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);

      expect(overlay.enqueue(chat('   ')), isFalse);
    });
  });

  group('DanmakuOverlaySession lifecycle', () {
    test('reports active-state changes once per transition', () async {
      final visibility = StreamController<bool>.broadcast();
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      addTearDown(visibility.close);
      final reported = <bool>[];
      overlay.onActiveChanged.listen(reported.add);
      overlay.bindVisibility(visibility.stream);

      visibility.add(true);
      visibility.add(true);
      await Future<void>.delayed(Duration.zero);
      visibility.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(reported, <bool>[true, false]);
    });

    test('unbindVisibility hides the surface', () async {
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);
      overlay.enqueue(chat('hello'));

      overlay.unbindVisibility();

      expect(overlay.isSurfaceVisible, isFalse);
      expect(overlay.length, 0);
    });

    test('rebinding replaces the previous subscription', () async {
      final first = StreamController<bool>.broadcast();
      final second = StreamController<bool>.broadcast();
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      addTearDown(first.close);
      addTearDown(second.close);

      overlay.bindVisibility(first.stream);
      first.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(overlay.isSurfaceVisible, isTrue);

      overlay.bindVisibility(second.stream);
      first.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(overlay.isSurfaceVisible, isTrue, reason: 'the replaced stream must not move the surface state');
    });

    test('a disposed overlay refuses further calls', () async {
      final overlay = DanmakuOverlaySession();
      await overlay.dispose();

      expect(() => overlay.enqueue(chat('hello')), throwsA(isA<StateError>()));
    });
  });

  group('DanmakuOverlaySession presentation', () {
    test('scales the font with the surface and clamps it', () {
      final overlay = DanmakuOverlaySession(
        config: DanmakuOverlayConfig.defaults.copyWith(
          fontSize: 14,
          referenceWidth: 360,
          minScale: 0.8,
          maxScale: 1.5,
        ),
      );
      addTearDown(overlay.dispose);

      expect(overlay.fontSizeFor(360), 14);
      expect(overlay.fontSizeFor(720), 21, reason: 'clamped at 1.5x');
      expect(overlay.fontSizeFor(90), closeTo(11.2, 0.001), reason: 'clamped at 0.8x');
      expect(overlay.fontSizeFor(0), 14, reason: 'an unknown width is not a reason to shrink');
    });

    test('scaling can be turned off', () {
      final overlay = DanmakuOverlaySession(
        config: DanmakuOverlayConfig.defaults.copyWith(scaleWithSurface: false),
      );
      addTearDown(overlay.dispose);

      expect(overlay.fontSizeFor(1000), DanmakuOverlayConfig.defaults.fontSize);
    });

    test('a fixed-placement message keeps its own duration', () async {
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);

      overlay.enqueue(
        chat('pinned', style: const DanmakuStyle(fontSize: 14, baseSpeed: 60, fontWeight: 400, placement: DanmakuPlacement.top, fixedDurationMs: 8000)),
      );

      expect(overlay.items.single.lifetime, const Duration(milliseconds: 8000));
    });

    test('a slower multiplier lengthens the lifetime', () async {
      final fast = DanmakuOverlaySession();
      final slow = DanmakuOverlaySession(config: DanmakuOverlayConfig.defaults.copyWith(speedMultiplier: 0.5));
      addTearDown(fast.dispose);
      addTearDown(slow.dispose);
      fast.bindVisibility(Stream<bool>.value(true));
      slow.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);

      fast.enqueue(chat('x'));
      slow.enqueue(chat('x'));

      expect(slow.items.single.lifetime, greaterThan(fast.items.single.lifetime));
    });

    test('evicts items whose lifetime has passed', () async {
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);
      final start = DateTime(2026, 9, 26, 12);
      overlay.enqueue(chat('one'), now: start);

      expect(overlay.evictExpired(now: start.add(const Duration(seconds: 1))), isEmpty);
      expect(overlay.length, 1);

      final expired = overlay.evictExpired(now: start.add(const Duration(minutes: 1)));

      expect(expired.single.message.text, 'one');
      expect(overlay.length, 0);
    });

    test('the display area follows the configured fraction', () {
      final overlay = DanmakuOverlaySession(config: DanmakuOverlayConfig.defaults.copyWith(displayAreaFraction: 0.5));
      addTearDown(overlay.dispose);

      expect(overlay.displayAreaFor(400), 200);
    });
  });

  group('DanmakuFanOutSink', () {
    test('feeds both surfaces with one accepted message', () async {
      final primary = _RecordingSink();
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);
      final sink = DanmakuFanOutSink(primary: primary, overlay: overlay, surfaceWidth: () => 320);

      sink.onDanmaku(chat('hello'));

      expect(primary.messages, <String>['hello']);
      expect(overlay.items.single.message.text, 'hello');
      expect(overlay.items.single.fontSize, lessThan(DanmakuOverlayConfig.defaults.fontSize));
    });

    test('forwards everything the overlay does not own', () {
      final primary = _RecordingSink();
      final sink = DanmakuFanOutSink(primary: primary);

      sink.onNotice(DanmakuNotice.connected);
      sink.onRoomChanged('room-1');

      expect(primary.notices, <String>['connected']);
    });

    test('clearing drops both surfaces', () async {
      final primary = _RecordingSink();
      final overlay = DanmakuOverlaySession();
      addTearDown(overlay.dispose);
      overlay.bindVisibility(Stream<bool>.value(true));
      await Future<void>.delayed(Duration.zero);
      final sink = DanmakuFanOutSink(primary: primary, overlay: overlay);
      sink.onDanmaku(chat('hello'));

      sink.clearRendered();

      expect(primary.clearCount, 1);
      expect(overlay.length, 0);
    });

    test('works without an overlay installed', () {
      final primary = _RecordingSink();
      final sink = DanmakuFanOutSink(primary: primary);

      sink.onDanmaku(chat('hello'));

      expect(primary.messages, <String>['hello']);
    });
  });
}
