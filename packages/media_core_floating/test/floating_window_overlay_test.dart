import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_floating/media_core_floating.dart';

Future<void> _pump(WidgetTester tester, {bool resizable = true}) async {
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
              resizableByDrag: resizable,
            ),
          ),
          resizeControlKey: const Key('resize-grip'),
          child: const ColoredBox(color: Color(0xFF112233)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('FloatingWindowOverlay resize grip', () {
    testWidgets('a corner drag resizes the window', (tester) async {
      await _pump(tester);

      final grip = find.byKey(const Key('resize-grip'));
      expect(grip, findsOneWidget);

      final before = tester.getSize(find.byType(ColoredBox));
      await tester.drag(grip, const Offset(60, 40));
      await tester.pump();

      final after = tester.getSize(find.byType(ColoredBox));
      expect(after.width, greaterThan(before.width));
      expect(after.height, greaterThan(before.height));
    });

    testWidgets('dragging the picture moves without resizing', (tester) async {
      await _pump(tester);

      final beforePosition = tester.getTopLeft(find.byType(ColoredBox));
      final beforeSize = tester.getSize(find.byType(ColoredBox));

      await tester.drag(find.byType(ColoredBox), const Offset(-40, -30));
      await tester.pump();

      expect(tester.getSize(find.byType(ColoredBox)), beforeSize);
      expect(tester.getTopLeft(find.byType(ColoredBox)), isNot(beforePosition));
    });

    testWidgets('no grip when the host turned resizing off', (tester) async {
      await _pump(tester, resizable: false);

      expect(find.byKey(const Key('resize-grip')), findsNothing);
    });
  });

  group('FloatingWindowOverlay remembered geometry', () {
    Future<StreamController<bool>> pumpWith({
      required WidgetTester tester,
      Rect? initialRect,
      ValueChanged<Rect>? onRectChanged,
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
              placement: const FloatingWindowPlacement(
                config: FloatingPlacementConfig(
                  width: 300,
                  height: 200,
                  minWidth: 100,
                  minHeight: 80,
                  snapToEdge: false,
                  resizableByDrag: true,
                ),
              ),
              initialRect: initialRect,
              onRectChanged: onRectChanged,
              child: const ColoredBox(color: Color(0xFF112233)),
            ),
          ),
        ),
      );
      await tester.pump();
      return visibility;
    }

    testWidgets('a remembered rect comes back instead of the anchor', (tester) async {
      const saved = Rect.fromLTWH(40, 60, 220, 140);
      await pumpWith(tester: tester, initialRect: saved);

      expect(tester.getTopLeft(find.byType(ColoredBox)), saved.topLeft);
      expect(tester.getSize(find.byType(ColoredBox)), saved.size);
    });

    testWidgets('a remembered rect off the surface is clamped back in', (tester) async {
      await pumpWith(tester: tester, initialRect: const Rect.fromLTWH(4000, 4000, 5000, 900));

      final rect = tester.getRect(find.byType(ColoredBox));
      final surface = tester.getSize(find.byType(FloatingWindowOverlay));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(surface.width));
      expect(rect.bottom, lessThanOrEqualTo(surface.height));
    });

    testWidgets('a settled drag and a hide both report the rect', (tester) async {
      Rect? reported;
      final visibility = await pumpWith(tester: tester, onRectChanged: (rect) => reported = rect);

      await tester.drag(find.byType(ColoredBox), const Offset(-40, -30));
      await tester.pump();
      expect(reported, isNotNull);
      expect(reported!.size, tester.getSize(find.byType(ColoredBox)));

      reported = null;
      visibility.add(false);
      await tester.pumpAndSettle();
      // 隐藏时再报一次：这是宿主最后能拿到的位置。
      expect(reported, isNotNull);
    });
  });

  group('FloatingWindowOverlay visibility', () {
    testWidgets('the visibility stream hides and re-shows the window', (tester) async {
      final visibility = StreamController<bool>.broadcast();
      addTearDown(visibility.close);

      Widget host() => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: FloatingWindowOverlay(
            visible: visibility.stream,
            initiallyVisible: true,
            placement: const FloatingWindowPlacement(
              config: FloatingPlacementConfig(width: 300, height: 200),
            ),
            child: const ColoredBox(color: Color(0xFF112233)),
          ),
        ),
      );

      await tester.pumpWidget(host());
      expect(find.byType(ColoredBox), findsOneWidget);

      visibility.add(false);
      await tester.pumpAndSettle();
      expect(find.byType(ColoredBox), findsNothing);

      visibility.add(true);
      await tester.pumpAndSettle();
      expect(find.byType(ColoredBox), findsOneWidget);

      // Disposing must drop the listener: a host that opens and closes the
      // window repeatedly would otherwise keep every dead state's callback.
      await tester.pumpWidget(const SizedBox.shrink());
      visibility.add(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
