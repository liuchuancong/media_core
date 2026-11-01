import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

import '../../../support/fakes.dart';

final DlnaService avTransport = DlnaService(
  serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
  controlUrl: Uri.parse('http://tv/av'),
);

void main() {
  group('SoapClient error mapping', () {
    test('a successful action surfaces its output arguments', () async {
      final transport = FakeSoapTransport(
        (url, headers, body) => const SoapHttpResponse(
          statusCode: 200,
          body: '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>
<u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<RelTime>00:01:00</RelTime><TrackDuration>00:45:00</TrackDuration>
</u:GetPositionInfoResponse></s:Body></s:Envelope>
''',
        ),
      );
      final client = SoapClient(transport: transport);

      final result = await client.invoke(service: avTransport, action: 'GetPositionInfo');

      expect(result.statusCode, 200);
      expect(result.argument('RelTime'), '00:01:00');
      expect(transport.sent, hasLength(1));
      expect(transport.sent.single.url, Uri.parse('http://tv/av'));
      expect(transport.sent.single.headers['SOAPAction'], contains('#GetPositionInfo'));
    });

    test('a UPnP fault becomes a typed, non-retriable device error', () async {
      final transport = FakeSoapTransport(
        (url, headers, body) => const SoapHttpResponse(
          statusCode: 500,
          body: '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault>
<detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>701</errorCode>
<errorDescription>Transition not available</errorDescription></UPnPError></detail>
</s:Fault></s:Body></s:Envelope>
''',
        ),
      );
      final client = SoapClient(transport: transport);

      await expectLater(
        client.invoke(service: avTransport, action: 'Pause'),
        throwsA(
          isA<DlnaUpnpException>()
              .having((e) => e.code, 'code', UpnpErrorCode.transitionUnavailable)
              .having((e) => e.retriable, 'retriable', isFalse)
              .having((e) => e.description, 'description', 'Transition not available'),
        ),
      );
    });

    test('a 401 fault means unsupported action', () async {
      final transport = FakeSoapTransport(
        (url, headers, body) => const SoapHttpResponse(
          statusCode: 500,
          body: '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault>
<detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>401</errorCode>
<errorDescription>Invalid Action</errorDescription></UPnPError></detail>
</s:Fault></s:Body></s:Envelope>
''',
        ),
      );
      final client = SoapClient(transport: transport);

      await expectLater(
        client.invoke(service: avTransport, action: 'Seek'),
        throwsA(isA<DlnaUnsupportedActionException>()),
      );
    });

    test('a non-2xx answer without a fault is a transport failure', () async {
      final transport = FakeSoapTransport(
        (url, headers, body) => const SoapHttpResponse(statusCode: 502, body: '<html>bad gateway</html>'),
      );
      final client = SoapClient(transport: transport);

      await expectLater(
        client.invoke(service: avTransport, action: 'Play'),
        throwsA(isA<DlnaSoapException>().having((e) => e.retriable, 'retriable', isTrue)),
      );
    });

    test('a stalled device is a timeout, not a hanging future', () async {
      final transport = FakeSoapTransport((url, headers, body) {
        throw TimeoutException('stalled');
      });
      final client = SoapClient(transport: transport);

      await expectLater(
        client.invoke(service: avTransport, action: 'Play'),
        throwsA(isA<DlnaTimeoutException>().having((e) => e.retriable, 'retriable', isTrue)),
      );
    });

    test('an unreachable device is a network failure', () async {
      final transport = FakeSoapTransport((url, headers, body) {
        throw const SocketException('connection refused');
      });
      final client = SoapClient(transport: transport);

      await expectLater(client.invoke(service: avTransport, action: 'Play'), throwsA(isA<DlnaNetworkException>()));
    });

    test('a bounded budget cuts off a device that never answers', () async {
      final transport = FakeSoapTransport((url, headers, body) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return const SoapHttpResponse(statusCode: 200, body: '<s:Envelope/>');
      });
      final client = SoapClient(transport: transport, timeout: const Duration(milliseconds: 50));

      await expectLater(client.invoke(service: avTransport, action: 'Play'), throwsA(isA<DlnaTimeoutException>()));
    });

    test('an action missing from the SCPD set is refused locally', () async {
      final transport = FakeSoapTransport(
        (url, headers, body) => const SoapHttpResponse(statusCode: 200, body: '<s:Envelope/>'),
      );
      final client = SoapClient(transport: transport);

      await expectLater(
        client.invoke(service: avTransport, action: 'Seek', supportedActions: const <String>{'Play', 'Pause'}),
        throwsA(isA<DlnaUnsupportedActionException>()),
      );
      expect(transport.sent, isEmpty, reason: 'the refusal must not reach the wire');
    });

    test('invokeWithRequest maps a prebuilt request the same way', () async {
      final transport = FakeSoapTransport(
        (url, headers, body) => const SoapHttpResponse(statusCode: 200, body: '<s:Envelope/>'),
      );
      final client = SoapClient(transport: transport);
      final request = SoapRequestBuilder.setUri(service: avTransport, url: 'http://media/a.mp4', didl: '');

      final result = await client.invokeWithRequest(service: avTransport, request: request);

      expect(result.action, request.action);
      expect(transport.sent.single.body, request.body);
    });
  });
}
