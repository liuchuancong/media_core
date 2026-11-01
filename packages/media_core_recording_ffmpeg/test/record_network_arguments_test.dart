import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';

/// The network options a recording adds are the difference between a stream
/// that resolves behind a proxy or on Android and one that does not. These
/// tests pin the placement and the protocol split: TLS options belong to
/// HTTPS only, the HTTP proxy belongs to both.
void main() {
  List<String> argumentsFor({required String url, String? proxy, String? caFile, bool tlsVerify = true}) {
    return FfmpegRecordArguments(
      config: FfmpegRecordConfig(proxy: proxy, caFile: caFile, tlsVerify: tlsVerify),
    ).recordArguments(
      url: url,
      outputDirectory: '/tmp/recording',
      segmentPattern: 'recording_%06d.clock-v1.ts',
      journalPath: '/tmp/recording/recording.clock-v1.csv',
      filePrefix: 'recording',
    );
  }

  test('an HTTPS input gets the CA bundle, verification switch and proxy before -i', () {
    final arguments = argumentsFor(
      url: 'https://example.com/live.m3u8',
      proxy: 'http://127.0.0.1:7897',
      caFile: '/data/certificates/cacert.pem',
      tlsVerify: false,
    );
    final inputIndex = arguments.indexOf('-i');

    expect(arguments, containsAllInOrder(['-tls_verify', '0']));
    expect(arguments, containsAllInOrder(['-ca_file', '/data/certificates/cacert.pem']));
    expect(arguments, containsAllInOrder(['-http_proxy', 'http://127.0.0.1:7897']));
    expect(arguments.indexOf('-tls_verify'), lessThan(inputIndex));
    expect(arguments.indexOf('-ca_file'), lessThan(inputIndex));
    expect(arguments.indexOf('-http_proxy'), lessThan(inputIndex));
  });

  test('a plain HTTP input gets the proxy but no TLS-only options', () {
    final arguments = argumentsFor(
      url: 'http://example.com/live.flv',
      proxy: 'http://127.0.0.1:7897',
      caFile: '/data/certificates/cacert.pem',
      tlsVerify: false,
    );

    expect(arguments, containsAllInOrder(['-http_proxy', 'http://127.0.0.1:7897']));
    expect(arguments, isNot(contains('-ca_file')));
    expect(arguments, isNot(contains('-tls_verify')));
  });

  test('the input gets the deep analysis window and can relax HLS extensions', () {
    final arguments = const FfmpegRecordArguments(config: FfmpegRecordConfig(extensionPicky: false)).recordArguments(
      url: 'https://example.com/live.m3u8',
      outputDirectory: '/tmp/recording',
      segmentPattern: 'recording_%06d.clock-v1.ts',
      journalPath: '/tmp/recording/recording.clock-v1.csv',
      filePrefix: 'recording',
    );
    expect(arguments, containsAllInOrder(['-analyzeduration', '20000000']));
    expect(arguments, containsAllInOrder(['-probesize', '10485760']));
    expect(arguments, containsAllInOrder(['-extension_picky', '0']));
  });

  test('a signed URL and header block are redacted for logs', () {
    const url = 'https://cdn.example.com/live.m3u8?token=secret&expires=1';
    expect(FfmpegRecordArguments.redactUrl(url), 'https://cdn.example.com/live.m3u8?<redacted>');
    expect(FfmpegRecordArguments.redactUrl('http://user:pass@127.0.0.1:7897/'), 'http://<credentials>@127.0.0.1:7897/');
    final arguments = FfmpegRecordArguments.redactArguments([
      '-headers',
      'Referer: https://example.com\r\nCookie: session=secret',
      '-i',
      url,
    ]);
    expect(arguments[1], '<redacted headers>');
    expect(arguments[3], 'https://cdn.example.com/live.m3u8?<redacted>');
  });

  test('verification stays on unless it was explicitly turned off', () {
    final arguments = argumentsFor(url: 'https://example.com/live.m3u8', caFile: '/data/certificates/cacert.pem');

    expect(arguments, containsAllInOrder(['-ca_file', '/data/certificates/cacert.pem']));
    expect(arguments, isNot(contains('-tls_verify')));
  });
}
