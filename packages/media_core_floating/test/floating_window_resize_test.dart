import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_floating/media_core_floating.dart';

/// Resize handles: every edge and corner moves its own side, and the side the
/// viewer did not grab stays where it was.
void main() {
  const surface = Size(1000, 800);
  const start = Rect.fromLTWH(100, 100, 300, 200);

  FloatingWindowPlacement placement({
    Set<FloatingResizeHandle> handles = FloatingResizeHandle.all,
    bool keepAspectRatio = false,
    double minWidth = 100,
    double minHeight = 80,
    double maxWidthFraction = 0.5,
  }) => FloatingWindowPlacement(
    config: FloatingPlacementConfig(
      minWidth: minWidth,
      minHeight: minHeight,
      maxWidthFraction: maxWidthFraction,
      resizeHandles: handles,
      resizeKeepsAspectRatio: keepAspectRatio,
    ),
  );

  group('FloatingWindowPlacement.resize', () {
    test('the right edge moves, the left edge and the top stay put', () {
      final rect = placement().resize(
        current: start,
        delta: const Offset(50, 0),
        surface: surface,
        handle: FloatingResizeHandle.right,
      );
      expect(rect.left, start.left);
      expect(rect.top, start.top);
      expect(rect.width, 350);
      expect(rect.height, start.height);
    });

    test('the left edge moves, the right edge stays put', () {
      final rect = placement().resize(
        current: start,
        delta: const Offset(-40, 0),
        surface: surface,
        handle: FloatingResizeHandle.left,
      );
      expect(rect.right, start.right);
      expect(rect.left, 60);
      expect(rect.width, 340);
    });

    test('the bottom edge moves, the top edge stays put', () {
      final rect = placement().resize(
        current: start,
        delta: const Offset(0, 60),
        surface: surface,
        handle: FloatingResizeHandle.bottom,
      );
      expect(rect.top, start.top);
      expect(rect.height, 260);
      expect(rect.width, start.width);
    });

    test('the top edge moves, the bottom edge stays put', () {
      final rect = placement().resize(
        current: start,
        delta: const Offset(0, 40),
        surface: surface,
        handle: FloatingResizeHandle.top,
      );
      expect(rect.bottom, start.bottom);
      expect(rect.top, 140);
      expect(rect.height, 160);
    });

    test('a corner moves both of its edges and keeps the opposite corner', () {
      final rect = placement().resize(
        current: start,
        delta: const Offset(-30, -20),
        surface: surface,
        handle: FloatingResizeHandle.topLeft,
      );
      expect(rect.right, start.right);
      expect(rect.bottom, start.bottom);
      expect(rect.left, 70);
      expect(rect.top, 80);
      expect(rect.width, 330);
      expect(rect.height, 220);
    });

    test('a shrink stops at the configured floors', () {
      final rect = placement().resize(
        current: start,
        delta: const Offset(-500, -500),
        surface: surface,
        handle: FloatingResizeHandle.bottomRight,
      );
      expect(rect.width, 100);
      expect(rect.height, 80);
      // The anchored (top-left) corner has not moved.
      expect(rect.left, start.left);
      expect(rect.top, start.top);
    });

    test('a grow stops at the surface width fraction', () {
      final rect = placement(maxWidthFraction: 0.4).resize(
        current: start,
        delta: const Offset(2000, 0),
        surface: surface,
        handle: FloatingResizeHandle.right,
      );
      expect(rect.width, 400);
    });

    test('a resize never leaves the surface', () {
      final rect = placement().resize(
        current: const Rect.fromLTWH(900, 700, 100, 100),
        delta: const Offset(-50, -50),
        surface: surface,
        handle: FloatingResizeHandle.topLeft,
      );
      expect(rect.right, lessThanOrEqualTo(surface.width));
      expect(rect.bottom, lessThanOrEqualTo(surface.height));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
    });

    test('with the aspect lock the dragged edge follows and the opposite one anchors', () {
      final rect = placement(keepAspectRatio: true).resize(
        current: start,
        delta: const Offset(60, 0),
        surface: surface,
        handle: FloatingResizeHandle.bottomRight,
        aspectRatio: 1.5,
      );
      // Width drove the resize; the height followed the ratio.
      expect(rect.width, closeTo(360, 0.001));
      expect(rect.height, closeTo(240, 0.001));
      expect(rect.left, start.left);
      expect(rect.top, start.top);
    });

    test('an empty handle set means no grip at all', () {
      final config = placement(handles: const <FloatingResizeHandle>{}).config;
      expect(config.effectiveResizeHandles, isEmpty);
      // The historical single bottom-right grip is still the default once the
      // window is resizable at all, and nothing is offered when it is not.
      expect(const FloatingPlacementConfig().effectiveResizeHandles, isEmpty);
      expect(
        const FloatingPlacementConfig(resizableByDrag: true).effectiveResizeHandles,
        <FloatingResizeHandle>{FloatingResizeHandle.bottomRight},
      );
      expect(
        const FloatingPlacementConfig(resizableByDrag: true, resizeHandles: FloatingResizeHandle.all)
            .effectiveResizeHandles,
        FloatingResizeHandle.all,
      );
      expect(
        const FloatingPlacementConfig(resizableByDrag: false, resizeHandles: FloatingResizeHandle.all)
            .effectiveResizeHandles,
        isEmpty,
      );
    });

    test('a handle knows which axes it moves', () {
      expect(FloatingResizeHandle.topLeft.isLeft, isTrue);
      expect(FloatingResizeHandle.topLeft.isTop, isTrue);
      expect(FloatingResizeHandle.topLeft.isRight, isFalse);
      expect(FloatingResizeHandle.topLeft.isCorner, isTrue);
      expect(FloatingResizeHandle.top.isCorner, isFalse);
      expect(FloatingResizeHandle.left.isCorner, isFalse);
      expect(FloatingResizeHandle.bottomRight.isCorner, isTrue);
      expect(FloatingResizeHandle.all, hasLength(8));
      expect(FloatingResizeHandle.corners, hasLength(4));
      expect(FloatingResizeHandle.edges, hasLength(4));
    });
  });

  group('FloatingWindowOverlay handles', () {
    Future<void> pump(
      WidgetTester tester, {
      required Set<FloatingResizeHandle> handles,
      bool withControls = false,
    }) async {
      final visibility = StreamController<bool>.broadcast();
      addTearDown(visibility.close);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: FloatingWindowOverlay(
              visible: visibility.stream,
              initiallyVisible: true,
              placement: FloatingWindowPlacement(
                config: FloatingPlacementConfig(
                  width: 300,
                  height: 200,
                  minWidth: 100,
                  minHeight: 80,
                  snapToEdge: false,
                  resizableByDrag: true,
                  resizeHandles: handles,
                  resizeKeepsAspectRatio: false,
                ),
              ),
              onExpand: withControls ? () {} : null,
              onClose: withControls ? () {} : null,
              resizeControlKey: const Key('resize-grip'),
              child: const ColoredBox(key: Key('window-content'), color: Color(0xFF112233)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('every configured edge and corner gets a grip', (tester) async {
      await pump(tester, handles: FloatingResizeHandle.all);
      for (final handle in FloatingResizeHandle.all) {
        final key = handle == FloatingResizeHandle.bottomRight
            ? const Key('resize-grip')
            : ValueKey<String>('floating-resize-${handle.name}');
        expect(find.byKey(key), findsOneWidget, reason: 'missing grip for ${handle.name}');
      }
    });

    testWidgets('only the requested handles appear', (tester) async {
      await pump(
        tester,
        handles: const <FloatingResizeHandle>{FloatingResizeHandle.left},
      );
      expect(find.byKey(const ValueKey<String>('floating-resize-left')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('floating-resize-right')), findsNothing);
      expect(find.byKey(const Key('resize-grip')), findsNothing);
    });

    testWidgets('an edge drag resizes from that side only', (tester) async {
      await pump(
        tester,
        handles: const <FloatingResizeHandle>{FloatingResizeHandle.left},
      );
      final before = tester.getRect(find.byKey(const Key('window-content')));
      await tester.drag(find.byKey(const ValueKey<String>('floating-resize-left')), const Offset(-40, 0));
      await tester.pump();
      final after = tester.getRect(find.byKey(const Key('window-content')));
      expect(after.right, closeTo(before.right, 0.001));
      expect(after.width, closeTo(before.width + 40, 0.001));
      expect(after.height, closeTo(before.height, 0.001));
    });

    testWidgets('the right edge grip is the legacy corner key', (tester) async {
      await pump(
        tester,
        handles: const <FloatingResizeHandle>{FloatingResizeHandle.bottomRight},
      );
      expect(find.byKey(const Key('resize-grip')), findsOneWidget);
      final before = tester.getSize(find.byKey(const Key('window-content')));
      await tester.drag(find.byKey(const Key('resize-grip')), const Offset(40, 30));
      await tester.pump();
      expect(tester.getSize(find.byKey(const Key('window-content'))).width, greaterThan(before.width));
    });

    testWidgets('the top strip keeps clear of the window controls', (tester) async {
      await pump(tester, handles: FloatingResizeHandle.all, withControls: true);
      final grip = tester.getRect(find.byKey(const ValueKey<String>('floating-resize-top')));
      final window = tester.getRect(find.byKey(const Key('window-content')));
      // Two 48 px controls sit in the top-right corner.
      expect(grip.right, lessThanOrEqualTo(window.right - 96));
    });
  });

  group('the window remembers what the viewer chose', () {
    Future<void> pumpRemembered(WidgetTester tester, {Rect? initialRect}) async {
      final visibility = StreamController<bool>.broadcast();
      addTearDown(visibility.close);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: FloatingWindowOverlay(
              visible: visibility.stream,
              initiallyVisible: true,
              initialRect: initialRect,
              placement: FloatingWindowPlacement(
                config: const FloatingPlacementConfig(
                  width: 300,
                  height: 200,
                  minWidth: 100,
                  minHeight: 80,
                  snapToEdge: false,
                  resizableByDrag: true,
                  resizeHandles: FloatingResizeHandle.all,
                  resizeKeepsAspectRatio: false,
                ),
              ),
              child: const ColoredBox(key: Key('window-content'), color: Color(0xFF112233)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a remembered rect is restored instead of the anchor', (tester) async {
      const remembered = Rect.fromLTWH(24, 60, 240, 160);
      await pumpRemembered(tester, initialRect: remembered);
      expect(tester.getRect(find.byKey(const Key('window-content'))), remembered);
    });

    testWidgets('an edge drag reports a resized window', (tester) async {
      await pumpRemembered(tester);
      final before = tester.getRect(find.byKey(const Key('window-content')));
      await tester.drag(find.byKey(const ValueKey<String>('floating-resize-right')), const Offset(40, 0));
      await tester.pump();
      final after = tester.getRect(find.byKey(const Key('window-content')));
      expect(after.width, closeTo(before.width + 40, 0.001));
      expect(after.height, closeTo(before.height, 0.001));
      // The window grew to the right and stayed on the surface.
      expect(after.right, lessThanOrEqualTo(800));
    });

    testWidgets('a remembered rect is clamped into a smaller surface', (tester) async {
      // Wider and further right than the 800x600 test surface can hold.
      const remembered = Rect.fromLTWH(700, 500, 400, 300);
      await pumpRemembered(tester, initialRect: remembered);
      final rect = tester.getRect(find.byKey(const Key('window-content')));
      expect(rect.right, lessThanOrEqualTo(800));
      expect(rect.bottom, lessThanOrEqualTo(600));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
    });
  });
}
