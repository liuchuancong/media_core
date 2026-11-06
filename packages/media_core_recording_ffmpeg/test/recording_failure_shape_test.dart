import 'package:flutter_test/flutter_test.dart';

import 'package:media_core_recording_ffmpeg/src/backend/recording_failure_shape.dart';

void main() {
  group('RecordingFailureShape.classify', () {
    test('an HTTP status the host answered names the address, not the network', () {
      final shape = RecordingFailureShape.classify(exitCode: 1, logTail: const [
        '[https] Opening input',
        'HTTP error 403 Forbidden',
        'Server returned 403 Forbidden',
      ]);
      expect(shape, RecordingFailureShape.addressRefused);
      expect(shape.refreshesSignedStream, isTrue);
    });

    test('an input cut mid stream reads as the CDN ending it', () {
      final shape = RecordingFailureShape.classify(exitCode: 255, logTail: const [
        'frame= 1200 fps=30',
        'Connection reset by peer',
      ]);
      expect(shape, RecordingFailureShape.unexpectedEof);
    });

    test('a kill with nothing on record takes the plain lane', () {
      expect(RecordingFailureShape.classify(exitCode: 255, logTail: const []), RecordingFailureShape.other);
      expect(RecordingFailureShape.classify(exitCode: null, logTail: const ['[tcp] connected']), RecordingFailureShape.other);
    });

    test('a network that refused the request refunds the retry', () {
      final shape = RecordingFailureShape.classify(exitCode: 1, logTail: const [
        'Connection refused',
        'Could not resolve host: live.example.com',
      ]);
      expect(shape, RecordingFailureShape.networkUnreachable);
      expect(shape.refreshesSignedStream, isFalse);
    });

    test('the newest words win when the tail holds several kinds', () {
      // The classifier reads the tail it is given; the backend keeps only the
      // last lines, so an hour-old refusal is gone by the time the process
      // ends on today's trouble.
      final shape = RecordingFailureShape.classify(exitCode: 1, logTail: const [
        '... two hours of media ...',
        'av_read_frame operation timed out',
      ]);
      expect(shape, RecordingFailureShape.networkUnreachable);
    });
  });
}
