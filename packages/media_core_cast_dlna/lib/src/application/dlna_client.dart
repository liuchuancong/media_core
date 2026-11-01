import 'dart:async';
import 'dart:io';

import 'package:media_core/media_core.dart';

import 'package:media_core_cast_dlna/src/application/discovery/dlna_discovery_manager.dart';
import 'package:media_core_cast_dlna/src/application/discovery/dlna_discovery_options.dart';
import 'package:media_core_cast_dlna/src/application/dlna_diagnostics.dart';
import 'package:media_core_cast_dlna/src/application/media/dlna_capability_resolver.dart';
import 'package:media_core_cast_dlna/src/application/media/dlna_media_selector.dart';
import 'package:media_core_cast_dlna/src/application/playback/dlna_playback_monitor.dart';
import 'package:media_core_cast_dlna/src/application/session/dlna_session.dart';
import 'package:media_core_cast_dlna/src/application/session/dlna_session_manager.dart';
import 'package:media_core_cast_dlna/src/domain/contracts/soap_transport.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_device.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_capability.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_resource.dart';
import 'package:media_core_cast_dlna/src/domain/enums/dlna_media_type.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/infrastructure/compatibility/device_compatibility.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/http_soap_transport.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_client.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/description_http_fetcher.dart';
import 'package:media_core_cast_dlna/src/infrastructure/discovery/ssdp/ssdp_client.dart';
import 'package:media_core_cast_dlna/src/infrastructure/media/http/media_http_server.dart';
import 'package:media_core_cast_dlna/src/utils/mime_type.dart';

final LogModule _log = MediaCoreLog.of(LogCategory.network);

/// The package's public facade (§28): discovery, sessions and local
/// media behind one object.
///
/// Hosts that want the protocol pieces à la carte use the classes
/// directly ([DlnaDiscoveryManager], [DlnaSessionManager],
/// [MediaHttpServer], [DlnaMediaSelector]); hosts that want the whole
/// flow use this.
final class DlnaClient {
  /// Creates a client.
  ///
  /// Every collaborator is injectable; the defaults this constructor
  /// creates are closed by [dispose], the caller's own are not.
  DlnaClient({
    SsdpSource? ssdp,
    DescriptionFetcher? fetchDescription,
    SoapTransport? transport,
    DlnaDiscoveryOptions? discoveryOptions,
    DlnaPlaybackMonitorOptions? monitorOptions,
    MediaHttpServer? mediaServer,
    this.enableGena = true,
    DeviceCompatibilityRegistry? compatibility,
  }) {
    _manager = DlnaDiscoveryManager(
      ssdp: ssdp,
      fetchDescription: fetchDescription,
      options: discoveryOptions ?? const DlnaDiscoveryOptions(),
    );
    _sessions = DlnaSessionManager(
      transport: transport,
      monitorOptions: monitorOptions ?? const DlnaPlaybackMonitorOptions(),
      enableGena: enableGena,
      compatibility: compatibility,
    );
    if (transport != null) {
      _transport = transport;
    } else {
      final http = HttpSoapTransport();
      _ownedTransport = http;
      _transport = http;
    }
    _providedMediaServer = mediaServer;
  }

  late final DlnaDiscoveryManager _manager;
  late final DlnaSessionManager _sessions;
  late final SoapTransport _transport;
  HttpSoapTransport? _ownedTransport;
  MediaHttpServer? _providedMediaServer;

  /// Per-device sink capability cache.
  final Map<String, DlnaMediaCapability> _capabilities = <String, DlnaMediaCapability>{};

  /// The media-server URL currently prepared per device.
  final Map<String, Uri> _served = <String, Uri>{};

  bool _closed = false;

  /// Whether AVTransport eventing (GENA) is attempted; off means
  /// sessions run purely on their polling fallback.
  final bool enableGena;

  /// Resolves the vendor-quirk profile each session runs under (§9);
  /// the default registry knows no vendors and always answers
  /// spec-conformant.

  /// The server local files are rewritten through; a host-provided one
  /// keeps its own lifecycle, a lazily created default is stopped by
  /// [dispose].
  MediaHttpServer get mediaServer => _providedMediaServer ?? (_ownedMediaServer ??= MediaHttpServer());

  MediaHttpServer? _ownedMediaServer;

  /// Starts SSDP discovery. Idempotent.
  Future<void> startDiscovery() async {
    _assertOpen();
    await _manager.start();
  }

  /// Stops SSDP discovery. Sessions stay usable.
  Future<void> stopDiscovery() => _manager.stop();

  /// The devices currently considered present, in discovery order.
  List<DlnaDevice> get devicesSnapshot => _manager.devices;

  /// Fires after every discovery mutation with the full snapshot.
  Stream<List<DlnaDevice>> get devices => _manager.devicesStream;

  /// A resolved device appeared for the first time.
  Stream<DlnaDevice> get deviceAdded => _manager.deviceAdded;

  /// A device's UDN left the set.
  Stream<String> get deviceRemoved => _manager.deviceRemoved;

  /// The device with this UDN, when currently present.
  DlnaDevice? device(String udn) => _manager.device(udn);

  /// Connects a cast session to [device]; connecting twice returns the
  /// same session.
  Future<DlnaSession> connect(DlnaDevice device) {
    _assertOpen();
    return _sessions.connect(device);
  }

  /// Ends a session this client created; media this client registered
  /// for the session's device is unregistered with it (§23.3 — the
  /// server itself stays up for the other sessions).
  Future<void> disconnect(DlnaSession session) async {
    final served = _served.remove(session.device.udn);
    if (served != null) {
      mediaServer.unregister(served);
    }
    await _sessions.disconnect(session);
  }

  /// Prepares media for [device]: local files are rewritten through
  /// the media server and the device's declared capabilities choose the
  /// resource, exactly as the backend adapter does.
  ///
  /// Throws [DlnaUnsupportedMediaException] when the device says it
  /// cannot play any offered resource; the caller surfaces that before
  /// any session is involved.
  Future<DlnaMedia> prepareMedia({
    required DlnaDevice device,
    required String title,
    required String url,
    String? mimeType,
    Duration? duration,
  }) async {
    _assertOpen();
    final capability = await _capabilityOf(device);
    final source = Uri.parse(url);
    final served = await _maybeServe(device, source);
    final uri = served ?? source;
    final resolvedMime = mimeType ?? MimeType.forPath(url);

    final selection = const DlnaMediaSelector().select(
      media: DlnaMedia(
        id: device.udn,
        title: title,
        mediaType: DlnaMediaType.fromMimeType(resolvedMime),
        sourceUri: source,
        resources: <DlnaMediaResource>[
          DlnaMediaResource(uri: uri, mimeType: resolvedMime, supportsByteRange: served != null),
        ],
      ),
      capability: capability,
    );
    if (selection.requiresTranscoding) {
      _log.warning(
        'device needs a converted stream; sending as-is',
        fields: <String, Object?>{'device': device.udn, 'reasons': selection.reasons.join(' | ')},
      );
    }
    return DlnaMedia(
      id: device.udn,
      title: title,
      mediaType: DlnaMediaType.fromMimeType(resolvedMime),
      sourceUri: source,
      duration: duration,
      mimeType: resolvedMime,
      resources: <DlnaMediaResource>[selection.resource],
    );
  }

  /// Takes a point-in-time diagnostic snapshot (§25.3).
  DlnaDiagnostics diagnostics() {
    return DlnaDiagnostics(
      discoveredDeviceCount: _manager.devices.length,
      activeSessionCount: _sessions.sessions.length,
      mediaServerRunning: mediaServer.isRunning,
      discoveryRunning: _manager.isRunning,
      capturedAt: DateTime.now(),
    );
  }

  /// Releases every session, the discovery run and owned transports.
  Future<void> dispose() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _manager.dispose();
    await _sessions.dispose();
    _ownedTransport?.close();
    await _ownedMediaServer?.stop();
  }

  void _assertOpen() {
    if (_closed) {
      throw const DlnaSessionException('client is disposed');
    }
  }

  Future<DlnaMediaCapability> _capabilityOf(DlnaDevice device) async {
    final cached = _capabilities[device.udn];
    if (cached != null) {
      return cached;
    }
    final connectionManager = device.connectionManager;
    if (connectionManager == null) {
      return const DlnaMediaCapability.unknown();
    }
    final capability = await DlnaCapabilityResolver(
      client: SoapClient(transport: _transport),
    ).resolve(connectionManager);
    _capabilities[device.udn] = capability;
    return capability;
  }

  Future<Uri?> _maybeServe(DlnaDevice device, Uri source) async {
    final file = _localFileOf(source.toString());
    if (file == null) {
      return null;
    }
    final server = mediaServer;
    if (!server.isRunning) {
      await server.start();
    }
    final previous = _served.remove(device.udn);
    if (previous != null) {
      server.unregister(previous);
    }
    final url = await server.registerFile(file);
    _served[device.udn] = url;
    return url;
  }

  File? _localFileOf(String url) {
    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    if (scheme == 'http' || scheme == 'https') {
      return null;
    }
    if (scheme == 'file') {
      return File(uri!.toFilePath());
    }
    if (scheme.length == 1) {
      return File(url);
    }
    if (scheme.isEmpty && (url.startsWith('/') || url.startsWith(r'\\'))) {
      return File(url);
    }
    return null;
  }
}
