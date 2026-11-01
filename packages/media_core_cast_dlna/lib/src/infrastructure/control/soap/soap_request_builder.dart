import 'dart:convert' show utf8;

import 'package:media_core_cast_dlna/src/domain/entities/dlna_service.dart';
import 'package:media_core_cast_dlna/src/utils/duration_parser.dart';

/// A rendered SOAP request: body plus the HTTP headers a UPnP control
/// POST must carry.
final class SoapRequest {
  /// Creates a request.
  const SoapRequest({required this.action, required this.body, required this.headers});

  /// The SOAP action header value (quoted, per UPnP).
  final String action;

  /// The envelope XML.
  final String body;

  /// HTTP headers: SOAPAction, Content-Type, Content-Length.
  final Map<String, String> headers;
}

/// Builds the SOAP envelopes UPnP control needs.
///
/// UPnP control is one POST per action with a document-typed body;
/// there is no session and no ordering guarantee across actions, so
/// the encoder is pure and stateless. Argument names match the service
/// SCPDs exactly — the device matches them literally, so a wrong
/// casing (or an `InstanceId` that should have been `InstanceID`) is a
/// 402/500 fault on every real device, not a portable slip.
abstract final class SoapRequestBuilder {
  /// `SetAVTransportURI`: load media on the device.
  static SoapRequest setUri({
    required DlnaService service,
    required String url,
    required String didl,
    int instanceId = 0,
  }) {
    return _request(
      service: service,
      action: 'SetAVTransportURI',
      arguments: <String, String>{'InstanceID': '$instanceId', 'CurrentURI': url, 'CurrentURIMetaData': didl},
    );
  }

  /// `Play` with the default `1` speed.
  static SoapRequest play({required DlnaService service, int instanceId = 0, String speed = '1'}) {
    return _request(
      service: service,
      action: 'Play',
      arguments: <String, String>{'InstanceID': '$instanceId', 'Speed': speed},
    );
  }

  /// `Pause`.
  static SoapRequest pause({required DlnaService service, int instanceId = 0}) {
    return _request(service: service, action: 'Pause', arguments: <String, String>{'InstanceID': '$instanceId'});
  }

  /// `Stop`.
  static SoapRequest stop({required DlnaService service, int instanceId = 0}) {
    return _request(service: service, action: 'Stop', arguments: <String, String>{'InstanceID': '$instanceId'});
  }

  /// `Seek` to an absolute REL_TIME target.
  static SoapRequest seek({
    required DlnaService service,
    required Duration target,
    int instanceId = 0,
    String unit = 'REL_TIME',
  }) {
    return _request(
      service: service,
      action: 'Seek',
      arguments: <String, String>{'InstanceID': '$instanceId', 'Unit': unit, 'Target': DurationCodec.format(target)},
    );
  }

  /// `GetPositionInfo` — position + duration + track identity in one
  /// round trip, which is why polling uses this and not
  /// GetTransportInfo separately.
  static SoapRequest getPositionInfo({required DlnaService service, int instanceId = 0}) {
    return _request(
      service: service,
      action: 'GetPositionInfo',
      arguments: <String, String>{'InstanceID': '$instanceId'},
    );
  }

  /// `GetTransportInfo`.
  static SoapRequest getTransportInfo({required DlnaService service, int instanceId = 0}) {
    return _request(
      service: service,
      action: 'GetTransportInfo',
      arguments: <String, String>{'InstanceID': '$instanceId'},
    );
  }

  /// `GetMediaInfo`.
  static SoapRequest getMediaInfo({required DlnaService service, int instanceId = 0}) {
    return _request(service: service, action: 'GetMediaInfo', arguments: <String, String>{'InstanceID': '$instanceId'});
  }

  /// `GetVolume` on RenderingControl.
  static SoapRequest getVolume({required DlnaService service, String channel = 'Master', int instanceId = 0}) {
    return _request(
      service: service,
      action: 'GetVolume',
      arguments: <String, String>{'InstanceID': '$instanceId', 'Channel': channel},
    );
  }

  /// `SetVolume` on RenderingControl.
  static SoapRequest setVolume({
    required DlnaService service,
    required int desiredVolume,
    String channel = 'Master',
    int instanceId = 0,
  }) {
    return _request(
      service: service,
      action: 'SetVolume',
      arguments: <String, String>{'InstanceID': '$instanceId', 'Channel': channel, 'DesiredVolume': '$desiredVolume'},
    );
  }

  /// `GetMute` on RenderingControl.
  static SoapRequest getMute({required DlnaService service, String channel = 'Master', int instanceId = 0}) {
    return _request(
      service: service,
      action: 'GetMute',
      arguments: <String, String>{'InstanceID': '$instanceId', 'Channel': channel},
    );
  }

  /// `SetMute` on RenderingControl.
  static SoapRequest setMute({
    required DlnaService service,
    required bool muted,
    String channel = 'Master',
    int instanceId = 0,
  }) {
    return _request(
      service: service,
      action: 'SetMute',
      arguments: <String, String>{'InstanceID': '$instanceId', 'Channel': channel, 'DesiredMute': muted ? '1' : '0'},
    );
  }

  /// `GetProtocolInfo` on ConnectionManager — the device's sink
  /// capabilities.
  static SoapRequest getProtocolInfo({required DlnaService service}) {
    return _request(service: service, action: 'GetProtocolInfo', arguments: const <String, String>{});
  }

  /// Builds an arbitrary action envelope for an action the prebuilt
  /// constructors do not cover.
  static SoapRequest invoke({
    required DlnaService service,
    required String action,
    Map<String, String> arguments = const <String, String>{},
  }) {
    return _request(service: service, action: action, arguments: arguments);
  }

  static SoapRequest _request({
    required DlnaService service,
    required String action,
    required Map<String, String> arguments,
  }) {
    final envelope = StringBuffer()
      ..write('<?xml version="1.0" encoding="utf-8"?>')
      ..write('<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" ')
      ..write('s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">')
      ..write('<s:Body>')
      ..write('<u:$action xmlns:u="${_escape(service.serviceType)}">');

    arguments.forEach((key, value) {
      envelope.write('<$key>${_escape(value)}</$key>');
    });

    envelope
      ..write('</u:$action>')
      ..write('</s:Body></s:Envelope>');

    final body = envelope.toString();
    final quoted = '"${service.serviceType}#$action"';

    return SoapRequest(
      action: quoted,
      body: body,
      headers: <String, String>{
        'SOAPAction': quoted,
        'Content-Type': 'text/xml; charset="utf-8"',
        // The transport writes the body as UTF-8, so the declared length
        // has to be the byte count: a CJK track title inside the DIDL
        // makes `body.length` (UTF-16 code units) too small and the
        // renderer reads a truncated envelope.
        'Content-Length': '${utf8.encode(body).length}',
      },
    );
  }

  static String _escape(String value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
