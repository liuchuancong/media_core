import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/identity/generation_id.dart';

void main() {
  group('GenerationId', () {
    test('keeps provided value', () {
      final id = GenerationId('gen-1');
      expect(id.value, 'gen-1');
    });

    test('rejects empty values', () {
      expect(() => GenerationId(''), throwsArgumentError);
    });

    test('generates unique identifiers', () {
      expect(GenerationId.generate(), isNot(GenerationId.generate()));
    });

    test('equality is value based', () {
      expect(GenerationId('g1'), GenerationId('g1'));
      expect(GenerationId('g1'), isNot(GenerationId('g2')));
    });

    test('isValid validates strings', () {
      expect(GenerationId.isValid('g'), isTrue);
      expect(GenerationId.isValid(''), isFalse);
    });

    test('fromJson round trips', () {
      expect(GenerationId.fromJson('g1').value, 'g1');
      expect(() => GenerationId.fromJson(true), throwsFormatException);
    });

    test('sorts by value', () {
      final ids = [GenerationId('2'), GenerationId('10'), GenerationId('1')]..sort();
      expect(ids.first.value, '1');
      expect(ids.last.value, '2');
    });
  });
}
