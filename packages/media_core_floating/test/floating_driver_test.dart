import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_floating/media_core_floating.dart';

final class _FakePresenter implements FloatingWindowPresenter {
  @override
  bool isSupported = true;

  int showCount = 0;
  int hideCount = 0;
  FloatingWindowRequest? lastRequest;

  @override
  Future<void> show(FloatingWindowRequest request) async {
    showCount++;
    lastRequest = request;
  }

  @override
  Future<void> hide() async => hideCount++;
}

PlayerId _player() => PlayerId('player_floating');

void main() {
  group('FloatingWindowPlacement size', () {
    const placement = FloatingWindowPlacement();

    test('follows a landscape video', () {
      final size = placement.sizeFor(surface: const Size(800, 600), videoWidth: 1920, videoHeight: 1080);

      expect(size.height, 90);
      expect(size.width, closeTo(160, 1));
    });

    test('follows a portrait video with a tall window', () {
      final size = placement.sizeFor(surface: const Size(800, 600), videoWidth: 1080, videoHeight: 1920);

      expect(size.width, closeTo(160, 1));
      expect(size.height, closeTo(284, 1));
    });

    test('falls back to the configured size when the video is unknown', () {
      expect(placement.sizeFor(surface: const Size(800, 600)), const Size(160, 90));
    });

    test('can ignore the video shape', () {
      final fixed = FloatingWindowPlacement(
        config: FloatingPlacementConfig.defaults.copyWith(aspectRatioFromVideo: false),
      );

      expect(fixed.sizeFor(surface: const Size(800, 600), videoWidth: 1080, videoHeight: 1920), const Size(160, 90));
    });

    test('never exceeds the configured fraction of the surface', () {
      const small = FloatingWindowPlacement(
        config: FloatingPlacementConfig(width: 400, height: 300, maxWidthFraction: 0.25),
      );

      expect(small.sizeFor(surface: const Size(800, 600)).width, 200, reason: 'a quarter of the surface width');
    });

    test('never shrinks below the configured minimum', () {
      const tiny = FloatingWindowPlacement(
        config: FloatingPlacementConfig(width: 10, height: 5, minWidth: 96, minHeight: 54),
      );

      expect(tiny.sizeFor(surface: const Size(800, 600)), const Size(96, 54));
    });
  });

  group('FloatingWindowPlacement position', () {
    const placement = FloatingWindowPlacement();
    const surface = Size(800, 600);
    const window = Size(160, 90);

    test('rests at the configured anchor with a margin', () {
      final rect = placement.rectFor(surface: surface, window: window);

      expect(rect.right, 800 - 12);
      expect(rect.bottom, 600 - 12);
    });

    test('honours an explicit anchor', () {
      final rect = placement.rectFor(surface: surface, window: window, anchor: FloatingAnchor.topLeft);

      expect(rect.left, 12);
      expect(rect.top, 12);
    });

    test('centres vertically on the side anchors', () {
      final rect = placement.rectFor(surface: surface, window: window, anchor: FloatingAnchor.centerRight);

      expect(rect.top, (600 - 90) / 2);
      expect(rect.right, 800 - 12);
    });

    test('clamps a drag inside the surface', () {
      final dragged = placement.drag(
        current: const Rect.fromLTWH(600, 500, 160, 90),
        delta: const Offset(400, 400),
        surface: surface,
      );

      expect(dragged.right, lessThanOrEqualTo(800));
      expect(dragged.bottom, lessThanOrEqualTo(600));
    });

    test('ignores a drag when dragging is disabled', () {
      const fixed = FloatingWindowPlacement(config: FloatingPlacementConfig(draggable: false));
      const current = Rect.fromLTWH(100, 100, 160, 90);

      expect(fixed.drag(current: current, delta: const Offset(50, 50), surface: surface), current);
    });
  });

  group('FloatingWindowPlacement snapping', () {
    const placement = FloatingWindowPlacement();
    const surface = Size(800, 600);

    test('snaps to the right edge when released near it', () {
      final snapped = placement.snap(rect: const Rect.fromLTWH(760, 200, 160, 90), surface: surface);

      expect(snapped.right, 800 - 12);
      expect(snapped.top, 200, reason: 'snapping is horizontal only');
    });

    test('snaps to the left edge when released near it', () {
      expect(placement.snap(rect: const Rect.fromLTWH(10, 200, 160, 90), surface: surface).left, 12);
    });

    test('leaves a window released mid-surface alone', () {
      const released = Rect.fromLTWH(300, 200, 160, 90);

      expect(placement.snap(rect: released, surface: surface), released);
    });

    test('respects a snapped-off configuration', () {
      const noSnap = FloatingWindowPlacement(config: FloatingPlacementConfig(snapToEdge: false));
      const released = Rect.fromLTWH(10, 200, 160, 90);

      expect(noSnap.snap(rect: released, surface: surface), released);
    });

    test('reports the nearest corner', () {
      expect(placement.nearestAnchor(rect: const Rect.fromLTWH(10, 10, 160, 90), surface: surface), FloatingAnchor.topLeft);
      expect(
        placement.nearestAnchor(rect: const Rect.fromLTWH(600, 500, 160, 90), surface: surface),
        FloatingAnchor.bottomRight,
      );
    });
  });

  group('FloatingDriver', () {
    test('tracks the small window without any platform call', () async {
      final driver = FloatingDriver();
      addTearDown(driver.dispose);
      await driver.initialize();

      await driver.apply(_player(), PresentationRequest.floating());

      expect(driver.isFloating, isTrue);
      expect(driver.isAvailable, isTrue, reason: 'an in-app window is a widget; every platform can show it');
      expect(driver.playerId, _player());
    });

    test('refuses modes another driver owns', () async {
      final driver = FloatingDriver();
      addTearDown(driver.dispose);
      await driver.initialize();

      for (final request in <PresentationRequest>[
        PresentationRequest.pip(),
        PresentationRequest.fullscreen(),
        PresentationRequest.windowFullscreen(),
      ]) {
        await expectLater(driver.apply(_player(), request), throwsA(isA<UnsupportedError>()));
      }
    });

    test('delegates to a host presenter when one is installed', () async {
      final presenter = _FakePresenter();
      final driver = FloatingDriver(presenter: presenter);
      addTearDown(driver.dispose);
      await driver.initialize();
      driver.onVideoSize(1920, 1080);

      await driver.apply(_player(), PresentationRequest.floating());
      await driver.apply(_player(), PresentationRequest.normal());

      expect(presenter.showCount, 1);
      expect(presenter.lastRequest?.playerId, 'player_floating');
      expect(presenter.lastRequest?.videoWidth, 1920);
      expect(presenter.hideCount, 1);
      expect(driver.isFloating, isFalse);
    });

    test('a host that installs its surface later is used', () async {
      final driver = FloatingDriver();
      addTearDown(driver.dispose);
      final presenter = _FakePresenter();
      await driver.initialize();
      driver.updatePresenter(presenter);

      await driver.apply(_player(), PresentationRequest.floating());

      expect(presenter.showCount, 1);
    });

    test('exposes the video size for the overlay', () async {
      final driver = FloatingDriver();
      addTearDown(driver.dispose);
      driver.onVideoSize(1920, 1080);

      expect(driver.videoWidth, 1920);
      expect(driver.videoHeight, 1080);
    });

    test('reports state changes once per transition', () async {
      final driver = FloatingDriver();
      addTearDown(driver.dispose);
      await driver.initialize();
      final reported = <bool>[];
      driver.onFloatingChanged.listen(reported.add);

      await driver.apply(_player(), PresentationRequest.floating());
      await driver.apply(_player(), PresentationRequest.floating());
      await driver.apply(_player(), PresentationRequest.normal());
      await Future<void>.delayed(Duration.zero);

      expect(reported, <bool>[true, false]);
    });

    test('dispose hides the surface', () async {
      final presenter = _FakePresenter();
      final driver = FloatingDriver(presenter: presenter);
      await driver.initialize();
      await driver.apply(_player(), PresentationRequest.floating());

      await driver.dispose();

      expect(presenter.hideCount, 1);
      expect(driver.isFloating, isFalse);
    });
  });

  group('FloatingWindowOverlay', () {
    Widget harness({
      required Stream<bool> visible,
      bool initiallyVisible = false,
      FloatingWindowPlacement placement = const FloatingWindowPlacement(),
      int? videoWidth,
      int? videoHeight,
      VoidCallback? onExpand,
      VoidCallback? onClose,
    }) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                FloatingWindowOverlay(
                  visible: visible,
                  initiallyVisible: initiallyVisible,
                  placement: placement,
                  videoWidth: videoWidth,
                  videoHeight: videoHeight,
                  onExpand: onExpand,
                  onClose: onClose,
                  expandControlKey: const ValueKey('expand'),
                  closeControlKey: const ValueKey('close'),
                  child: Container(key: const ValueKey('video'), color: const Color(0xFF000000)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('renders nothing while hidden', (tester) async {
      await tester.pumpWidget(harness(visible: const Stream<bool>.empty()));

      expect(find.byKey(const ValueKey('video')), findsNothing);
    });

    testWidgets('places the video at the anchor when visible', (tester) async {
      await tester.pumpWidget(harness(visible: const Stream<bool>.empty(), initiallyVisible: true));

      final rect = tester.getRect(find.byKey(const ValueKey('video')));
      expect(rect.right, 800 - 12);
      expect(rect.bottom, 600 - 12);
      expect(rect.size, const Size(160, 90));
    });

    testWidgets('shapes the window after the video', (tester) async {
      await tester.pumpWidget(
        harness(visible: const Stream<bool>.empty(), initiallyVisible: true, videoWidth: 1080, videoHeight: 1920),
      );

      final rect = tester.getRect(find.byKey(const ValueKey('video')));
      expect(rect.width, closeTo(160, 1));
      expect(rect.height, greaterThan(rect.width));
    });

    testWidgets('appears and disappears with the visibility stream', (tester) async {
      final visible = StreamController<bool>.broadcast();
      addTearDown(visible.close);
      await tester.pumpWidget(harness(visible: visible.stream));

      visible.add(true);
      // One pump delivers the stream event, the next rebuilds with it.
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('video')), findsOneWidget);

      visible.add(false);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('video')), findsNothing);
    });

    testWidgets('follows a drag and snaps on release', (tester) async {
      await tester.pumpWidget(
        harness(
          visible: const Stream<bool>.empty(),
          initiallyVisible: true,
          placement: const FloatingWindowPlacement(
            config: FloatingPlacementConfig(anchor: FloatingAnchor.topLeft, dragSnapThreshold: 600),
          ),
        ),
      );
      final before = tester.getRect(find.byKey(const ValueKey('video')));

      await tester.drag(find.byKey(const ValueKey('video')), const Offset(500, 120));
      await tester.pump();

      final after = tester.getRect(find.byKey(const ValueKey('video')));
      expect(after.left, greaterThan(before.left));
      expect(after.top, greaterThan(before.top));
      expect(after.right, 800 - 12, reason: 'released far from the left edge, so it snapped right');
    });

    testWidgets('calls back from the expand and close controls', (tester) async {
      var expanded = 0;
      var closed = 0;
      await tester.pumpWidget(
        harness(
          visible: const Stream<bool>.empty(),
          initiallyVisible: true,
          onExpand: () => expanded++,
          onClose: () => closed++,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('expand')));
      await tester.tap(find.byKey(const ValueKey('close')));

      expect(expanded, 1);
      expect(closed, 1);
    });

    testWidgets('omits the controls the host did not ask for', (tester) async {
      await tester.pumpWidget(harness(visible: const Stream<bool>.empty(), initiallyVisible: true));

      expect(find.byKey(const ValueKey('expand')), findsNothing);
      expect(find.byKey(const ValueKey('close')), findsNothing);
    });
  });
}
