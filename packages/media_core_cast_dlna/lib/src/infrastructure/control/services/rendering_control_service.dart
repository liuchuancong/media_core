import 'package:media_core_cast_dlna/src/domain/entities/dlna_service.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/infrastructure/compatibility/device_compatibility.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_client.dart';

/// Typed facade over a device's RenderingControl service (§12.4):
/// volume and mute on the Master channel.
///
/// Like `AvTransportService`, the class is stateless — the session owns
/// state; this only speaks the protocol. UPnP defines the volume
/// channel as 0..100; values are clamped before they reach the wire
/// because out-of-range values are a device-side 402 on most
/// firmwares, not a portable slip.
final class RenderingControlService {
  /// Creates a service.
  ///
  /// [supportedActions], when loaded from the service's SCPD, refuses
  /// locally what the device does not declare.
  const RenderingControlService({
    required SoapClient client,
    required this.service,
    this.supportedActions,
    this.profile = const DeviceCompatibilityProfile.standard(),
  }) : _client = client;

  /// The RenderingControl endpoint this facade drives.
  final DlnaService service;

  /// The action names the device's SCPD declares, when known.
  final Set<String>? supportedActions;

  /// The compatibility profile governing this device's quirks.
  final DeviceCompatibilityProfile profile;

  final SoapClient _client;

  /// The effective instance id: the caller's explicit choice wins, the
  /// profile's is the default (§13.4).
  int _id(int? explicitId) => explicitId ?? profile.instanceId;

  /// Reads the Master volume (0..100).
  Future<int> getVolume({String channel = 'Master', int? instanceId}) async {
    final result = await _client.invoke(
      service: service,
      action: 'GetVolume',
      arguments: <String, String>{'InstanceID': '${_id(instanceId)}', 'Channel': channel},
      supportedActions: supportedActions,
    );
    return _parseVolume(result.argument('CurrentVolume'));
  }

  /// Sets the Master volume; returns the applied value (clamped).
  Future<int> setVolume(int percent, {String channel = 'Master', int? instanceId}) async {
    final desired = percent.clamp(0, 100);
    await _client.invoke(
      service: service,
      action: 'SetVolume',
      arguments: <String, String>{'InstanceID': '$instanceId', 'Channel': channel, 'DesiredVolume': '$desired'},
      supportedActions: supportedActions,
    );
    return desired;
  }

  /// Reads the Master mute state.
  Future<bool> isMuted({String channel = 'Master', int? instanceId}) async {
    final result = await _client.invoke(
      service: service,
      action: 'GetMute',
      arguments: <String, String>{'InstanceID': '${_id(instanceId)}', 'Channel': channel},
      supportedActions: supportedActions,
    );
    return _parseMute(result.argument('CurrentMute'));
  }

  /// Sets the Master mute state.
  Future<void> setMute({required bool muted, String channel = 'Master', int? instanceId}) async {
    await _client.invoke(
      service: service,
      action: 'SetMute',
      arguments: <String, String>{'InstanceID': '$instanceId', 'Channel': channel, 'DesiredMute': muted ? '1' : '0'},
      supportedActions: supportedActions,
    );
  }

  static int _parseVolume(String? raw) {
    final value = int.tryParse(raw?.trim() ?? '');
    if (value == null) {
      throw const DlnaSoapException('device answered GetVolume without a usable CurrentVolume');
    }
    return value.clamp(0, 100);
  }

  static bool _parseMute(String? raw) {
    final value = raw?.trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'yes';
  }
}
