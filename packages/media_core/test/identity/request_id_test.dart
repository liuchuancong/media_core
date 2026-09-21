import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/identity/request_id.dart';

void main() {
  group('RequestId', () {
    test('keeps provided value', () {
      final id = RequestId('req-1');
      expect(id.value, 'req-1');
    });

    test('rejects empty values', () {
      expect(() => RequestId(''), throwsArgumentError);
    });

    test('generates unique identifiers', () {
      expect(RequestId.generate(), isNot(RequestId.generate()));
    });

    test('equality is value based', () {
      expect(RequestId('r1'), RequestId('r1'));
      expect(RequestId('r1'), isNot(RequestId('r2')));
    });

    test('isValid validates strings', () {
      expect(RequestId.isValid('r'), isTrue);
      expect(RequestId.isValid(''), isFalse);
    });

    test('fromJson and toJson round trip', () {
      expect(RequestId.fromJson('r1').value, 'r1');
      expect(RequestId('r2').toJson(), 'r2');
    });
  });
}
