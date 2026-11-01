import 'dart:async';

import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

/// A scripted [SsdpSource]: tests feed announcements into [controller]
/// and the discovery pipeline consumes them as if they came off a real
/// multicast socket.
final class ScriptedSsdpSource implements SsdpSource {
  /// The feed tests write to.
  final controller = StreamController<SsdpMessage>.broadcast();

  /// How many times a search cycle was requested.
  int searches = 0;

  /// Whether stop was called; the controller stays open so tests can
  /// keep feeding it after a manager stopped listening.
  bool stopped = false;

  @override
  Stream<SsdpMessage> get messages => controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> search() async {
    searches++;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

/// A canonical "accepted" SOAP answer for transports that only need to
/// say 200.
const fakeResponseOk = SoapHttpResponse(statusCode: 200, body: '<s:Envelope></s:Envelope>');

/// An AVTransport SOAP stack scripted with PLAYING/45:00 answers;
/// every action name is recorded in arrival order.
final class ScriptedAvTransport {
  /// Creates a stack.
  ScriptedAvTransport({this.actions = const <String>{}});

  /// Actions the (virtual) SCPD declares; an empty set means "no SCPD
  /// loaded", so nothing is refused locally.
  Set<String> actions;

  final FakeSoapTransport transport = FakeSoapTransport((url, headers, body) {
    final action = headers['SOAPAction'] ?? '';
    if (action.contains('GetTransportInfo')) {
      return const SoapHttpResponse(statusCode: 200, body: avTransportInfoResponse);
    }
    if (action.contains('GetPositionInfo')) {
      return const SoapHttpResponse(statusCode: 200, body: avTransportPositionInfoResponse);
    }
    return fakeResponseOk;
  });

  /// The action names in arrival order (`Play`, `Seek`, ...).
  List<String> get sent => transport.sent
      .map((request) => (request.headers['SOAPAction'] ?? '').split('#').last.replaceAll('"', ''))
      .toList();

  /// A device whose answer for [action] throws, simulating a wire or
  /// device failure.
  void failAction(String action, Exception error) {
    transport.respond = (url, headers, body) {
      final soapAction = headers['SOAPAction'] ?? '';
      if (soapAction.contains('#$action')) {
        throw error;
      }
      return fakeResponseOk;
    };
  }
}

/// A GetTransportInfo answer reporting PLAYING.
const String avTransportInfoResponse = '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>
<u:GetTransportInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<CurrentTransportState>PLAYING</CurrentTransportState>
<CurrentTransportStatus>OK</CurrentTransportStatus>
<CurrentSpeed>1</CurrentSpeed>
</u:GetTransportInfoResponse></s:Body></s:Envelope>
''';

/// A GetPositionInfo answer at 1:00 of 45:00.
const String avTransportPositionInfoResponse = '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>
<u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<RelTime>00:01:00</RelTime><TrackDuration>00:45:00</TrackDuration>
<TrackURI>http://media/a.mp4</TrackURI>
</u:GetPositionInfoResponse></s:Body></s:Envelope>
''';

/// A GENA transport scripted per request.
final class ScriptedGenaTransport implements GenaTransport {
  /// The responder.
  FutureOr<GenaHttpResponse> Function(String method, Uri url, Map<String, String> headers)? onRequest;

  /// Every request, in order.
  final List<({String method, Uri url, Map<String, String> headers})> sent =
      <({String method, Uri url, Map<String, String> headers})>[];

  @override
  Future<GenaHttpResponse> request(String method, Uri url, Map<String, String> headers) async {
    sent.add((method: method, url: url, headers: Map<String, String>.of(headers)));
    final responder = onRequest;
    if (responder == null) {
      return const GenaHttpResponse(statusCode: 200, headers: <String, String>{});
    }
    return await responder(method, url, headers);
  }
}

/// A SOAP transport that answers from [respond] and records everything
/// it was asked to send.
final class FakeSoapTransport implements SoapTransport {
  /// Creates a transport.
  FakeSoapTransport(this.respond);

  /// Every posted exchange, in order.
  final List<PostedRequest> sent = <PostedRequest>[];

  /// The responder: returns the answer (sync or async), or throws to
  /// simulate a wire failure. Mutable so tests can re-script a transport
  /// mid-test.
  FutureOr<SoapHttpResponse> Function(Uri url, Map<String, String> headers, String body) respond;

  @override
  Future<SoapHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    sent.add(PostedRequest(url: url, headers: Map<String, String>.of(headers), body: body));
    return await respond(url, headers, body);
  }
}

/// One recorded POST.
final class PostedRequest {
  /// Creates a record.
  const PostedRequest({required this.url, required this.headers, required this.body});

  /// The control URL.
  final Uri url;

  /// The request headers.
  final Map<String, String> headers;

  /// The request body.
  final String body;
}

/// A minimal renderer description every discovery test can resolve.
const String tvDescription = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>Salon TV</friendlyName>
    <manufacturer>Anyka</manufacturer>
    <modelName>K7</modelName>
    <UDN>uuid:TV-001</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>/av</controlURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/rc</controlURL>
      </service>
    </serviceList>
  </device>
</root>
''';

/// Builds an alive announcement.
SsdpMessage aliveMessage({String usn = 'uuid:TV-001', String location = 'http://192.168.1.40/desc.xml'}) {
  return SsdpMessage(
    method: 'NOTIFY',
    headers: <String, String>{
      'nt': 'urn:schemas-upnp-org:device:MediaRenderer:1',
      'nts': 'ssdp:alive',
      'usn': usn,
      'location': location,
      'cache-control': 'max-age=1800',
    },
  );
}

/// Builds a departure announcement.
SsdpMessage byebyeMessage({String usn = 'uuid:TV-001'}) {
  return SsdpMessage(
    method: 'NOTIFY',
    headers: <String, String>{'nt': 'ssdp:byebye', 'nts': 'ssdp:byebye', 'usn': usn},
  );
}

/// Builds the synthetic expiry the SSDP client emits for an
/// announcement nobody renewed.
SsdpMessage expiredMessage({String usn = 'uuid:TV-001'}) {
  return SsdpMessage(method: 'EXPIRED', headers: <String, String>{'usn': usn});
}
