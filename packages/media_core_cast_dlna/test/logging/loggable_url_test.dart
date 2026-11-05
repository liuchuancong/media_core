import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/src/logging/loggable_url.dart';

void main() {
  test('loggableUrl strips the query so tokens never reach a sink', () {
    final url = Uri.parse('http://192.168.1.42:8123/media/item.mp4?token=secret&pos=12');
    final safe = loggableUrl(url);

    expect(safe, 'http://192.168.1.42:8123/media/item.mp4');
    expect(safe, isNot(contains('token')));
  });
}
