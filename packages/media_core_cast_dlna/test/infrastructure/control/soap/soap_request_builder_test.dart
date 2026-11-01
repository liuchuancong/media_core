import 'dart:convert' show utf8;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

final DlnaService avTransport = DlnaService(
  serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
  controlUrl: Uri.parse('http://tv/av'),
);

final DlnaService renderingControl = DlnaService(
  serviceType: 'urn:schemas-upnp-org:service:RenderingControl:1',
  controlUrl: Uri.parse('http://tv/rc'),
);

void main() {
  group('SoapRequestBuilder', () {
    test('envelopes carry the exact argument names devices match literally', () {
      final play = SoapRequestBuilder.play(service: avTransport);

      expect(play.action, '"urn:schemas-upnp-org:service:AVTransport:1#Play"');
      expect(play.body, contains('<InstanceID>0</InstanceID>'));
      expect(play.body, contains('<Speed>1</Speed>'));
      expect(play.headers['Content-Type'], contains('text/xml'));
      expect(play.headers['SOAPAction'], play.action);
    });

    test('the declared Content-Length counts UTF-8 bytes, not code units', () {
      final setUri = SoapRequestBuilder.setUri(
        service: avTransport,
        url: 'http://media/黑镜.mp4',
        didl: '<DIDL-Lite><dc:title>黑镜</dc:title></DIDL-Lite>',
      );

      final declared = int.parse(setUri.headers['Content-Length']!);

      // The CJK title makes UTF-16 length differ from the byte count;
      // the header must carry the byte count the transport writes.
      expect(declared, utf8.encode(setUri.body).length);
      expect(declared, isNot(setUri.body.length));
    });

    test('setUri escapes markup in the URI and metadata', () {
      final setUri = SoapRequestBuilder.setUri(
        service: avTransport,
        url: 'http://media/a&b<c>.mp4',
        didl: '<DIDL-Lite/>',
      );

      expect(setUri.body, contains('a&amp;b&lt;c&gt;.mp4'));
      expect(setUri.action, contains('#SetAVTransportURI'));
    });

    test('seek encodes a REL_TIME clock string', () {
      final seek = SoapRequestBuilder.seek(service: avTransport, target: const Duration(minutes: 65, seconds: 3));

      expect(seek.body, contains('<Unit>REL_TIME</Unit>'));
      expect(seek.body, contains('<Target>01:05:03</Target>'));
    });

    test('transport and media info actions exist for polling', () {
      expect(SoapRequestBuilder.getTransportInfo(service: avTransport).action, contains('#GetTransportInfo'));
      expect(SoapRequestBuilder.getPositionInfo(service: avTransport).action, contains('#GetPositionInfo'));
      expect(SoapRequestBuilder.getMediaInfo(service: avTransport).action, contains('#GetMediaInfo'));
    });

    test('rendering control actions carry the channel', () {
      final setVolume = SoapRequestBuilder.setVolume(service: renderingControl, desiredVolume: 42);
      final setMute = SoapRequestBuilder.setMute(service: renderingControl, muted: true);

      expect(setVolume.body, contains('<Channel>Master</Channel>'));
      expect(setVolume.body, contains('<DesiredVolume>42</DesiredVolume>'));
      expect(setMute.body, contains('<DesiredMute>1</DesiredMute>'));
      expect(SoapRequestBuilder.getMute(service: renderingControl).action, contains('#GetMute'));
    });

    test('connection manager and generic invocations work', () {
      final protocolInfo = SoapRequestBuilder.getProtocolInfo(service: avTransport);
      final custom = SoapRequestBuilder.invoke(
        service: avTransport,
        action: 'SetPlayMode',
        arguments: <String, String>{'InstanceID': '0', 'NewPlayMode': 'REPEAT_ALL'},
      );

      expect(protocolInfo.action, contains('#GetProtocolInfo'));
      expect(custom.body, contains('<NewPlayMode>REPEAT_ALL</NewPlayMode>'));
    });

    test('responses are read by local name across namespace prefixes', () {
      const response = '''
<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
 <s:Body>
  <u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
   <RelTime>00:00:42.000</RelTime>
   <TrackDuration>00:00:00</TrackDuration>
  </u:GetPositionInfoResponse>
 </s:Body>
</s:Envelope>
''';

      expect(SoapResponseParser.argument(response, 'RelTime'), '00:00:42.000');
      expect(SoapResponseParser.arguments(response), <String, String>{
        'RelTime': '00:00:42.000',
        'TrackDuration': '00:00:00',
      });
      expect(SoapResponseParser.argument(response, 'Missing'), isNull);
      expect(SoapResponseParser.arguments('<broken'), isEmpty);
    });
  });

  group('SoapFaultParser', () {
    test('a device fault decodes its UPnP error code', () {
      const fault = '''
<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
 <s:Body><s:Fault>
  <faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring>
  <detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
   <errorCode>501</errorCode><errorDescription>Invalid Action</errorDescription>
  </UPnPError></detail>
 </s:Fault></s:Body>
</s:Envelope>
''';

      final parsed = SoapFaultParser.parse(fault);

      expect(parsed, isNotNull);
      expect(parsed!.errorCode, '501');
      expect(parsed.codeNumber, 501);
      expect(parsed.code, UpnpErrorCode.actionFailed);
      expect(parsed.errorDescription, 'Invalid Action');
    });

    test('codes classify, and unknown codes stay unknown', () {
      SoapFault make(String code) {
        return SoapFaultParser.parse('''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault>
<detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>$code</errorCode>
</UPnPError></detail></s:Fault></s:Body></s:Envelope>
''')!;
      }

      expect(make('701').code, UpnpErrorCode.transitionUnavailable);
      expect(make('704').code, UpnpErrorCode.formatNotSupported);
      expect(make('402').code, UpnpErrorCode.invalidArgs);
      expect(make('9999').code, UpnpErrorCode.unknown);
    });

    test('no fault and no XML both mean "no fault"', () {
      expect(SoapFaultParser.parse('<s:Envelope></s:Envelope>'), isNull);
      expect(SoapFaultParser.parse('<html>502</html>'), isNull);
    });
  });

  group('wire format', () {
    test('the declared content length matches the bytes on the wire', () async {
      // A loopback exchange, because the byte count only means
      // something once a real HTTP stack has carried it.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = <String, String>{};
      server.listen((request) async {
        received['soapAction'] = request.headers.value('SOAPAction') ?? '';
        received['contentType'] = request.headers.contentType?.toString() ?? '';
        received['contentLength'] = request.headers.contentLength.toString();
        await request.drain<void>();
        request.response.write(
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body> '
          '<u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"> '
          '<RelTime>00:00:07</RelTime><TrackDuration>00:03:00</TrackDuration>'
          '</u:GetPositionInfoResponse></s:Body></s:Envelope>',
        );
        await request.response.close();
      });

      final transport = HttpSoapTransport();
      final service = DlnaService(
        serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
        controlUrl: Uri.parse('http://127.0.0.1:${server.port}/av'),
      );
      final request = SoapRequestBuilder.setUri(
        service: service,
        url: 'http://media/第四集.mp4',
        didl: '<DIDL-Lite><dc:title>第四集</dc:title></DIDL-Lite>',
      );
      final response = await transport.post(service.controlUrl, request.headers, request.body);

      expect(response.statusCode, 200);
      expect(received['soapAction'], request.action);
      expect(received['contentType'], contains('text/xml'));
      expect(int.parse(received['contentLength']!), utf8.encode(request.body).length);

      transport.close();
      await server.close(force: true);
    });
  });
}
