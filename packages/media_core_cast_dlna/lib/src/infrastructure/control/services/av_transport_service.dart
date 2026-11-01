import 'package:media_core_cast_dlna/src/domain/entities/dlna_service.dart';
import 'package:media_core_cast_dlna/src/domain/enums/dlna_transport_state.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/infrastructure/compatibility/device_compatibility.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_client.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_request_builder.dart';
import 'package:media_core_cast_dlna/src/utils/duration_parser.dart';

/// What `GetTransportInfo` answered.
final class AvTransportState {
  /// Creates a state answer.
  const AvTransportState({required this.transportState, this.transportStatus, this.speed});

  /// The classified transport state.
  final DlnaTransportState transportState;

  /// The device's transport status string (`OK`, `ERROR_OCCURRED`, ...).
  final String? transportStatus;

  /// The play speed, when reported.
  final String? speed;
}

/// What `GetPositionInfo` answered.
final class AvTransportPosition {
  /// Creates a position answer.
  const AvTransportPosition({this.position, this.duration, this.trackUri});

  /// The relative playhead position.
  final Duration? position;

  /// The current track duration.
  final Duration? duration;

  /// The URI of the loaded track, when the device reports one.
  final String? trackUri;
}

/// What `GetMediaInfo` answered.
final class AvTransportMedia {
  /// Creates a media answer.
  const AvTransportMedia({this.currentUri, this.mediaDuration, this.nextUri});

  /// The URI the device currently plays.
  final String? currentUri;

  /// The declared media duration.
  final Duration? mediaDuration;

  /// The queued next URI, when the device supports one.
  final String? nextUri;
}

/// Typed facade over a device's AVTransport service.
///
/// Every action is one SOAP call with the spec-exact arguments; every
/// answer is decoded into a typed record. The class holds no state —
/// sessions and monitors own state; this only speaks the protocol.
///
/// [supportedActions], when loaded from the service's SCPD, makes the
/// service refuse locally what the device has declared it cannot do
/// (§13.3): the refusal arrives as [DlnaUnsupportedActionException]
/// before any bytes reach the wire.
///
/// [profile] carries the vendor quirks (Phase 9): instance id, SOAP
/// action quoting, Seek unit, Play speed. Every field defaults to the
/// spec answer, so a spec-conformant device runs on the standard
/// profile without noticing the layer exists.
final class AvTransportService {
  /// Creates a service.
  const AvTransportService({
    required SoapClient client,
    required this.service,
    this.supportedActions,
    this.profile = const DeviceCompatibilityProfile.standard(),
  }) : _client = client;

  /// The AVTransport endpoint this facade drives.
  final DlnaService service;

  /// The action names the device's SCPD declares, when known.
  final Set<String>? supportedActions;

  /// The compatibility profile governing this device's quirks.
  final DeviceCompatibilityProfile profile;

  final SoapClient _client;

  /// `SetAVTransportURI` with DIDL [metadata].
  Future<void> setUri(String url, String metadata, {int? instanceId}) async {
    final request = SoapRequestBuilder.setUri(service: service, url: url, didl: metadata, instanceId: _id(instanceId));
    await _client.invokeWithRequest(
      service: service,
      request: _applyQuirks(request),
      supportedActions: supportedActions,
    );
  }

  /// `Play` at [speed] (defaults to the profile's speed; `1` on every
  /// basic renderer).
  Future<void> play({String? speed, int? instanceId}) {
    return _invoke('Play', <String, String>{
      'InstanceID': '${_id(instanceId)}',
      'Speed': speed ?? profile.playSpeed,
    }, instanceId: instanceId);
  }

  /// `Pause`.
  Future<void> pause({int? instanceId}) => _invoke('Pause', <String, String>{'InstanceID': '${_id(instanceId)}'});

  /// `Stop`.
  Future<void> stop({int? instanceId}) => _invoke('Stop', <String, String>{'InstanceID': '${_id(instanceId)}'});

  /// `Seek` to an absolute target in the profile's unit.
  Future<void> seek(Duration target, {int? instanceId}) async {
    final request = SoapRequestBuilder.seek(
      service: service,
      target: target,
      instanceId: _id(instanceId),
      unit: profile.seekUnit,
    );
    await _client.invokeWithRequest(
      service: service,
      request: _applyQuirks(request),
      supportedActions: supportedActions,
    );
  }

  /// `GetTransportInfo`.
  Future<AvTransportState> getTransportInfo({int? instanceId}) async {
    final result = await _invoke('GetTransportInfo', <String, String>{
      'InstanceID': '${_id(instanceId)}',
    }, instanceId: instanceId);
    return AvTransportState(
      transportState: DlnaTransportState.fromUpnp(result.argument('CurrentTransportState')),
      transportStatus: result.argument('CurrentTransportStatus'),
      speed: result.argument('CurrentSpeed'),
    );
  }

  /// `GetPositionInfo`.
  Future<AvTransportPosition> getPositionInfo({int? instanceId}) async {
    final result = await _invoke('GetPositionInfo', <String, String>{
      'InstanceID': '${_id(instanceId)}',
    }, instanceId: instanceId);
    return AvTransportPosition(
      position: DurationCodec.tryParse(result.argument('RelTime')),
      duration: DurationCodec.tryParse(result.argument('TrackDuration')),
      trackUri: _usable(result.argument('TrackURI')),
    );
  }

  /// `GetMediaInfo`.
  Future<AvTransportMedia> getMediaInfo({int? instanceId}) async {
    final result = await _invoke('GetMediaInfo', <String, String>{
      'InstanceID': '${_id(instanceId)}',
    }, instanceId: instanceId);
    return AvTransportMedia(
      currentUri: _usable(result.argument('CurrentURI')),
      mediaDuration: DurationCodec.tryParse(result.argument('MediaDuration')),
      nextUri: _usable(result.argument('NextURI')),
    );
  }

  /// The single execution path: every action request is built, its
  /// profile quirks applied, then posted — quirks cannot be bypassed by
  /// taking a different door.
  Future<SoapActionResult> _invoke(String action, Map<String, String> arguments, {int? instanceId}) {
    return _client.invokeWithRequest(
      service: service,
      request: _applyQuirks(SoapRequestBuilder.invoke(service: service, action: action, arguments: arguments)),
      supportedActions: supportedActions,
    );
  }

  /// The effective instance id: the caller's explicit choice wins, the
  /// profile's is the default (§13.4).
  int _id(int? explicitId) => explicitId ?? profile.instanceId;

  /// Applies the profile's wire-format quirks to a built request —
  /// currently the unquoted `SOAPACTION` header some stacks demand.
  SoapRequest _applyQuirks(SoapRequest request) {
    if (!profile.unquotedSoapAction) {
      return request;
    }
    final unquoted = request.action.replaceAll('"', '');
    final headers = <String, String>{
      for (final entry in request.headers.entries)
        if (entry.key == 'SOAPAction') 'SOAPAction': unquoted else entry.key: entry.value,
    };
    return SoapRequest(action: unquoted, body: request.body, headers: headers);
  }

  /// Devices answer `NOT_IMPLEMENTED` and empty strings for fields they
  /// do not track; neither is a URI.
  static String? _usable(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.toUpperCase() == 'NOT_IMPLEMENTED' ? null : value;
  }
}
