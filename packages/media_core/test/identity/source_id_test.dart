import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/identity/source_id.dart';

void main() {
  group('SourceId', () {
    test('keeps provided value', () {
      final id = SourceId('src-1');
      expect(id.value, 'src-1');
    });

    test('rejects empty values', () {
      expect(() => SourceId(''), throwsArgumentError);
    });

    test('unknown is a stable sentinel', () {
      expect(SourceId.unknown(), SourceId.unknown());
      expect(SourceId.unknown().value, 'unknown');
    });

    test('generates unique identifiers', () {
      expect(SourceId.generate(), isNot(SourceId.generate()));
    });

    test('equality is value based', () {
      expect(SourceId('a'), SourceId('a'));
      expect(SourceId('a'), isNot(SourceId('b')));
    });

    test('isValid validates strings', () {
      expect(SourceId.isValid('x'), isTrue);
      expect(SourceId.isValid(' '), isFalse);
    });

    test('fromJson and toJson round trip', () {
      expect(SourceId.fromJson('s1').value, 's1');
      expect(SourceId('s2').toJson(), 's2');
    });
  });
}
