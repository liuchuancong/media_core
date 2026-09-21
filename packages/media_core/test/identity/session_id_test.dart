import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/identity/session_id.dart';

void main() {
  group('SessionId', () {
    test('keeps provided value', () {
      final id = SessionId('session-1');
      expect(id.value, 'session-1');
      expect(id.rawValue, 'session-1');
    });

    test('rejects empty values', () {
      expect(() => SessionId(''), throwsArgumentError);
    });

    test('generates unique identifiers', () {
      expect(SessionId.generate(), isNot(SessionId.generate()));
    });

    test('equality is value based', () {
      expect(SessionId('a'), SessionId('a'));
      expect(SessionId('a'), isNot(SessionId('b')));
    });

    test('isValid validates strings', () {
      expect(SessionId.isValid('s'), isTrue);
      expect(SessionId.isValid(''), isFalse);
    });

    test('fromJson and toJson round trip', () {
      expect(SessionId.fromJson('s1').value, 's1');
      expect(SessionId('s2').toJson(), 's2');
      expect(() => SessionId.fromJson(1), throwsFormatException);
    });

    test('sorts by value', () {
      final ids = [SessionId('c'), SessionId('a'), SessionId('b')]..sort();
      expect(ids.map((id) => id.value).toList(), ['a', 'b', 'c']);
    });
  });
}
