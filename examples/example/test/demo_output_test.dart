import 'package:flutter_test/flutter_test.dart';

import 'package:example/demos/module_demo.dart';
import 'package:example/demos/registry.dart';

/// Every console demo actually runs.
///
/// A demo that throws is worse than no demo: a developer who clones the
/// repository and taps the first entry takes the failure as the framework's
/// state. The demos are pure logic on purpose — no device, no network — so
/// running all of them here is cheap, and it is the only check that keeps a
/// printed tour honest.
void main() {
  // The platform demo asks about permissions through a plugin, so the test
  // binding has to exist even though nothing is rendered.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('module tour', () {
    test('every demo runs and produces output', () async {
      expect(moduleDemos, isNotEmpty);

      for (final demo in moduleDemos) {
        final output = await demo.run();

        expect(output.trim(), isNotEmpty, reason: '${demo.id} printed nothing');
        expect(output, isNot(contains('❌')), reason: '${demo.id} reported an exception');
        expect(output.length, greaterThan(80), reason: '${demo.id} printed a stub');
      }
    });

    test('demo metadata is complete and unique', () {
      final ids = <String>{};

      for (final demo in moduleDemos) {
        expect(ids.add(demo.id), isTrue, reason: 'duplicate demo id ${demo.id}');
        expect(demo.nameZh, isNotEmpty);
        expect(demo.nameEn, isNotEmpty);
        expect(demo.purposeZh, isNotEmpty);
        expect(demo.purposeEn, isNotEmpty);
        expect(demo.pointsZh, isNotEmpty);
        expect(demo.pointsEn, isNotEmpty);
        expect(demo.snippet, isNotEmpty);
      }
    });

    test('every category with demos is reachable from the catalog', () {
      final withDemos = ModuleCategory.values.where(hasModuleDemos).toList();

      expect(withDemos, isNotEmpty);
      expect(
        withDemos.length,
        ModuleCategory.values.length,
        reason: 'a category with no demo is a category the catalog silently hides',
      );
    });
  });
}
