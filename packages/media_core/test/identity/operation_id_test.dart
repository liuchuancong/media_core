import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/identity/operation_id.dart';

void main() {
  group('OperationId', () {
    test('keeps provided value', () {
      final id = OperationId('op-1');
      expect(id.value, 'op-1');
    });

    test('rejects empty values', () {
      expect(() => OperationId(''), throwsArgumentError);
    });

    test('generates unique identifiers', () {
      expect(OperationId.generate(), isNot(OperationId.generate()));
    });

    test('equality is value based', () {
      expect(OperationId('o1'), OperationId('o1'));
      expect(OperationId('o1'), isNot(OperationId('o2')));
    });

    test('isValid validates strings', () {
      expect(OperationId.isValid('o'), isTrue);
      expect(OperationId.isValid(''), isFalse);
    });

    test('fromJson round trips', () {
      expect(OperationId.fromJson('o1').value, 'o1');
    });
  });
}
