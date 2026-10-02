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
}
