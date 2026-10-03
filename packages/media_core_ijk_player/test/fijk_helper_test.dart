import 'package:flutter_test/flutter_test.dart';

import 'package:media_core_ijk_player/src/fijk_helper.dart';

void main() {
  group('FijkHelper.sourceHeaderOptions', () {
    test('lifts user-agent out and joins the rest as CRLF lines', () {
      final options = FijkHelper.sourceHeaderOptions(<String, String>{
        'User-Agent': 'test-agent',
        'Referer': 'https://www.bilibili.com/',
      });

      expect(options['user_agent'], 'test-agent');
      expect(options['headers'], 'Referer:https://www.bilibili.com/\r\n');
      expect(options['headers'], isNot(contains('User-Agent')));
    });

    test('a header name carrying a newline or colon is dropped', () {
      // ijkplayer writes names verbatim into its CRLF-joined `headers`
      // option, so an unchecked name would inject a whole extra header
      // line into the request the CDN sees.
      final options = FijkHelper.sourceHeaderOptions(<String, String>{
        'X-Ok': 'kept',
        'X-Bad\r\nInjected: yes': 'value',
        'Host:evil.example.com': 'value',
      });

      final headers = options['headers']! as String;

      expect(headers, contains('X-Ok:kept'));
      expect(headers, isNot(contains('Injected')));
      expect(headers, isNot(contains('evil.example.com')));
    });

    test('CR and LF inside a value are neutralized, not dropped', () {
      final options = FijkHelper.sourceHeaderOptions(<String, String>{
        'Cookie': 'a=1\r\nX-Injected: yes',
      });

      final headers = options['headers']! as String;

      // The newline became a space, so the injected text is now part of
      // the Cookie value instead of a header line of its own: exactly one
      // CRLF terminator, at the end.
      expect(headers, 'Cookie:a=1 X-Injected: yes\r\n');
      expect(headers.split('\r\n').where((l) => l.isNotEmpty), hasLength(1));
    });

    test('empty names and values are skipped', () {
      final options = FijkHelper.sourceHeaderOptions(<String, String>{
        '': 'value',
        'X-Empty': '   ',
      });

      expect(options['headers'], isEmpty);
      expect(options.containsKey('user_agent'), isFalse);
    });
  });
}
