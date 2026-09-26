import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart' hide FloatingController;
import 'package:media_core_floating/media_core_floating.dart';

final class _FakePlayer implements PortablePlayer {
  _FakePlayer(this.id);

  @override
  final PlayerId id;

  bool disposed = false;

  @override
  int get videoWidth => 1080;

  @override
  int get videoHeight => 1920;

  @override
  PlayerHandle? get handle => null;

  @override
  bool get isDisposed => disposed;
}

final class _FakeRegistry implements PortablePlayerRegistry {
  _FakeRegistry(this.players);

  final Map<String, _FakePlayer> players;

  @override
  PortablePlayer? find(PlayerId id) => players[id.value];
}

PlayerId _id(String value) => PlayerId(value);

void main() {
  late _FakeRegistry registry;
  late _FakePlayer player;
  late FloatingDriver driver;
  late FloatingSessionController controller;

  setUp(() {
    player = _FakePlayer(_id('player-a'));
    registry = _FakeRegistry(<String, _FakePlayer>{'player-a': player});
    driver = FloatingDriver();
    controller = FloatingSessionController(
      driver: driver,
      registry: registry,
      surfaceBuilder: (context, playerId) => Container(
        key: ValueKey('surface-${playerId.value}'),
        color: const Color(0xFF000000),
      ),
    );
  });

  tearDown(() async {
    await controller.dispose();
    await driver.dispose();
  });

  group('FloatingSessionController handover', () {
    test('carries a live player into the small window', () async {
      await controller.show(_id('player-a'));

      expect(controller.isActive, isTrue);
      expect(driver.isFloating, isTrue);
      expect(controller.hasCarriedPlayer, isTrue);
      expect(driver.videoWidth, 1080);
      expect(driver.videoHeight, 1920);
    });

    test('refuses a player the page already disposed', () async {
      player.disposed = true;

      await expectLater(controller.show(_id('player-a')), throwsA(isA<StateError>()));
      expect(controller.isActive, isFalse);
    });

    test('hiding the window leaves the player running', () async {
      await controller.show(_id('player-a'));

      await controller.hide();

      expect(controller.isActive, isFalse);
      expect(player.disposed, isFalse);
      expect(controller.hasCarriedPlayer, isTrue);
    });

    test('toggle shows and hides', () async {
      await controller.toggle(_id('player-a'));
      expect(controller.isActive, isTrue);

      await controller.toggle(_id('player-a'));
      expect(controller.isActive, isFalse);
    });
  });

  group('FloatingSessionController auto-enter policy', () {
    test('opens when the page goes away while playing', () async {
      expect(await controller.onPageExit(playerId: _id('player-a'), playing: true), isTrue);
      expect(controller.isActive, isTrue);
    });

    test('stays put when the video is paused', () async {
      expect(await controller.onPageExit(playerId: _id('player-a'), playing: false), isFalse);
    });

    test('a backgrounded app does not open an in-app window by default', () async {
      expect(await controller.onAppBackgrounded(playerId: _id('player-a'), playing: true), isFalse);
      expect(controller.isActive, isFalse);
    });

    test('a host that wants the background trigger can enable it', () async {
      final host = FloatingSessionController(
        driver: driver,
        registry: registry,
        autoEnter: FloatingAutoEnterPolicy.defaults.copyWith(onAppBackground: true),
        surfaceBuilder: (context, playerId) => const SizedBox.shrink(),
      );
      addTearDown(host.dispose);

      expect(await host.onAppBackgrounded(playerId: _id('player-a'), playing: true), isTrue);
      expect(host.isActive, isTrue);
    });

    test('page exit can be switched off', () async {
      final host = FloatingSessionController(
        driver: driver,
        registry: registry,
        autoEnter: FloatingAutoEnterPolicy.defaults.copyWith(onPageExit: false),
        surfaceBuilder: (context, playerId) => const SizedBox.shrink(),
      );
      addTearDown(host.dispose);

      expect(await host.onPageExit(playerId: _id('player-a'), playing: true), isFalse);
    });
  });

  group('FloatingSessionController overlay', () {
    testWidgets('builds an overlay that appears with the small window', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  Builder(
                    builder: (context) => controller.buildOverlay(context, _id('player-a')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('surface-player-a')), findsNothing);

      await controller.show(_id('player-a'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('surface-player-a')), findsOneWidget);
    });

    testWidgets('the close control hides the small window', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [Builder(builder: (context) => controller.buildOverlay(context, _id('player-a')))],
              ),
            ),
          ),
        ),
      );
      await controller.show(_id('player-a'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(Semantics).last);
      await tester.pump();

      expect(controller.isActive, isFalse);
    });

    test('refuses to build a surface for a player with no handle and no builder', () {
      final bare = FloatingSessionController(driver: driver, registry: registry);
      addTearDown(bare.dispose);

      expect(() => bare.buildSurface(_FakeBuildContext(), _id('player-a')), throwsA(isA<StateError>()));
    });
  });
}

/// Minimal context stand-in: `buildSurface` only passes it to a builder.
class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
