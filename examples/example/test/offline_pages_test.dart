import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/demos/registry.dart';
import 'package:example/language.dart';
import 'package:example/pages/memory_demo_page.dart';
import 'package:example/pages/multiview_demo_page.dart';

/// The offline pages mount, react and tear down.
///
/// Both run on fakes, which is exactly why they can be tested: a fake player is
/// a `PoolPlayerHost`, so the wall's controller is the real one and a mount
/// failure here is a real one. Timers are driven with explicit `pump`s rather
/// than `pumpAndSettle`: the wall ticks on a periodic timer on purpose, and
/// `pumpAndSettle` would wait for it forever.
void main() {
  Future<void> mount(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      DemoLanguageScope(
        notifier: DemoLanguageNotifier(DemoLanguage.zh),
        child: MaterialApp(home: page),
      ),
    );
  }

  testWidgets('memory dashboard reports holdings and moves the pressure level', (tester) async {
    await mount(tester, const MemoryDemoPage());

    expect(find.text('内存监控 / Memory'), findsOneWidget);
    expect(find.text('normal'), findsOneWidget);

    // Fill the accounts; the pressure banner must follow.
    await tester.tap(find.text('上报一批占用'));
    await tester.pump();

    expect(find.text('pool'), findsOneWidget);
    expect(find.text('danmaku'), findsOneWidget);

    // And releasing everything goes back to normal.
    await tester.tap(find.text('全部释放'));
    await tester.pump();

    expect(find.text('normal'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('multiview wall fills its cells and follows the focus', (tester) async {
    await mount(tester, const MultiviewDemoPage());

    expect(find.text('多画面同看 / Multiview'), findsOneWidget);

    await tester.tap(find.text('填充画面'));
    // The fake players open asynchronously; a few pumps let that settle without
    // waiting on the wall's periodic tick.
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('gate-north'), findsOneWidget);
    expect(find.text('2×2'), findsOneWidget);

    // 3x3 replaces the layout and refills it.
    await tester.tap(find.text('3×3'));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('nine · 9 cells'), findsOneWidget, reason: 'the chip follows the layout');
    expect(find.textContaining('layout → nine (9 cells)'), findsOneWidget, reason: 'and the log explains it');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('the catalog exposes the two offline pages', () {
    final ids = runnableDemos.map((demo) => demo.id).toList();

    expect(ids, contains('memory'));
    expect(ids, contains('multiview'));
    expect(ids.first, 'player', reason: 'a developer should land on a player, not on a dashboard');
  });
}
