import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_capability.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_service.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/domain/value_objects/media_protocol_info.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_client.dart';

/// Resolves a device's sink capabilities over `GetProtocolInfo`.
///
/// Phase 4's rule is that capability comes from the device, not from a
/// brand table. A device without a ConnectionManager service, or one
/// whose answer cannot be read, resolves to
/// [DlnaMediaCapability.unknown] — selection then proceeds permissively
/// instead of blocking a TV that simply says less.
final class DlnaCapabilityResolver {
  /// Creates a resolver.
  const DlnaCapabilityResolver({required SoapClient client}) : _client = client;

  final SoapClient _client;

  /// Queries [connectionManager] for the sink protocol info.
  ///
  /// Any failure (offline device, SOAP fault, missing argument) lands
  /// on the unknown capability, because "the TV did not answer a
  /// capability probe" must not be escalated into "the TV cannot play
  /// anything".
  Future<DlnaMediaCapability> resolve(DlnaService connectionManager) async {
    try {
      final result = await _client.invoke(service: connectionManager, action: 'GetProtocolInfo');
      final sink = result.argument('Sink');
      if (sink == null || sink.trim().isEmpty) {
        return const DlnaMediaCapability.unknown();
      }
      return DlnaMediaCapability.fromSink(MediaProtocolInfo.parseList(sink));
    } on DlnaException {
      return const DlnaMediaCapability.unknown();
    }
  }
}
