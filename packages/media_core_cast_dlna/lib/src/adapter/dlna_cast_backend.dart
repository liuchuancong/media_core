import 'dart:async';
import 'dart:io';

import 'package:media_core/media_core.dart';

import 'package:media_core_cast_dlna/src/adapter/didl_lite.dart';
import 'package:media_core_cast_dlna/src/application/discovery/dlna_discovery_manager.dart';
import 'package:media_core_cast_dlna/src/application/discovery/dlna_discovery_options.dart';
import 'package:media_core_cast_dlna/src/application/media/dlna_capability_resolver.dart';
import 'package:media_core_cast_dlna/src/application/media/dlna_media_selector.dart';
import 'package:media_core_cast_dlna/src/domain/contracts/soap_transport.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_device.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_capability.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_resource.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media_selection.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_service.dart';
import 'package:media_core_cast_dlna/src/domain/enums/dlna_media_type.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/http_soap_transport.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_client.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_request_builder.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/description_http_fetcher.dart';
import 'package:media_core_cast_dlna/src/infrastructure/discovery/ssdp/ssdp_client.dart';
import 'package:media_core_cast_dlna/src/infrastructure/media/http/media_http_server.dart';
import 'package:media_core_cast_dlna/src/logging/dlna_log.dart';
import 'package:media_core_cast_dlna/src/utils/duration_parser.dart';
import 'package:media_core_cast_dlna/src/utils/mime_type.dart';

final LogModule _log = MediaCoreLog.of(LogCategory.network);

/// Whether the [DlnaLog]-to-MediaCoreLog bridge has been installed;
/// the bridge is process-wide and installing it twice would double
/// every core record.
bool _logBridgeInstalled = false;

/// Routes the core layers' neutral [DlnaLogEvent]s into media_core's
/// logging hub (§25): categories map onto [LogCategory] (everything
/// wire-level lands on network; playback and session keep their own),
/// levels pass through.
void _installLogBridge() {
  if (_logBridgeInstalled) {
    return;
  }
  _logBridgeInstalled = true;
  DlnaLog.sink = (event) {
    final category = switch (event.category) {
      DlnaLogCategory.playback => LogCategory.playback,
      DlnaLogCategory.session => LogCategory.session,
      DlnaLogCategory.mediaSelection => LogCategory.source,
      DlnaLogCategory.discovery ||
      DlnaLogCategory.ssdp ||
      DlnaLogCategory.deviceDescription ||
      DlnaLogCategory.soap ||
      DlnaLogCategory.gena ||
      DlnaLogCategory.mediaServer ||
      DlnaLogCategory.compatibility => LogCategory.network,
    };
    final log = MediaCoreLog.of(category);
    switch (event.level) {
      case DlnaLogLevel.debug:
        log.debug(event.message, fields: event.fields);
      case DlnaLogLevel.info:
        log.info(event.message, fields: event.fields);
      case DlnaLogLevel.warning:
        log.warning(event.message, error: event.error, fields: event.fields);
      case DlnaLogLevel.error:
        log.error(event.message, error: event.error, fields: event.fields);
    }
  };
}

/// [MediaCastBackend] over DLNA/UPnP: SSDP to find, HTTP+SOAP to
/// drive.
///
/// This adapter is the seam between media_core's protocol-neutral
/// casting contract and the DLNA core of this package: discovery and
/// description resolution are delegated to [DlnaDiscoveryManager],
/// control exchanges to [SoapClient], and the adapter's own job is
/// translation — [DlnaDevice] to [CastDevice], [DlnaException] to
/// [CastException], manager streams to backend events.
///
/// The DLNA model in one paragraph: SSDP announces devices with a
/// `LOCATION` pointing at a description document; that document lists
/// service control URLs; every action is one SOAP POST to a control
/// URL. There is no session and no authentication — which is exactly
/// why casting a URL the TV cannot fetch (token-gated with headers
/// only the app may send) fails *at the device*, and this backend's
/// duty is to surface that as a refused command rather than pretend
/// the cast succeeded.
class DlnaCastBackend implements MediaCastBackend {
  /// Creates a backend.
  ///
  /// Every collaborator is injectable so the whole class is testable
  /// without a network: a scripted [SsdpSource], a [fetchDescription]
  /// that returns canned XML, and a [transport] that answers SOAP
  /// envelopes from a table. Objects the caller passes in keep their
  /// own lifecycle; only the defaults this constructor creates are
  /// closed by [dispose].
  DlnaCastBackend({
    SsdpSource? discovery,
    DescriptionFetcher? fetchDescription,
    SoapTransport? transport,
    DlnaDiscoveryOptions? options,
    MediaHttpServer? mediaServer,
  }) {
    _installLogBridge();
    _manager = DlnaDiscoveryManager(
      ssdp: discovery,
      fetchDescription: fetchDescription,
      options: options ?? const DlnaDiscoveryOptions(),
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
  late final SoapTransport _transport;
  HttpSoapTransport? _ownedTransport;
  MediaHttpServer? _ownedMediaServer;
  MediaHttpServer? _providedMediaServer;

  /// The server local files are rewritten through; a host-provided one
  /// keeps its own lifecycle, a lazily created default is stopped by
  /// [dispose].
  MediaHttpServer get _mediaServer => _providedMediaServer ?? (_ownedMediaServer ??= MediaHttpServer());

  late SoapClient _soap;

  /// Per-device sink capability cache; a device that answered once
  /// keeps its answer for the backend's lifetime.
  final Map<String, DlnaMediaCapability> _capabilities = <String, DlnaMediaCapability>{};

  /// The media-server URL currently cast per device, so the previous
  /// registration can be dropped when a new cast replaces it.
  final Map<String, Uri> _served = <String, Uri>{};

  final StreamController<CastEvent> _events = StreamController<CastEvent>.broadcast();
  StreamSubscription<DlnaDevice>? _added;
  StreamSubscription<String>? _removed;
  StreamSubscription<DlnaDiscoveryError>? _errors;

  bool _started = false;
  bool _closed = false;

  @override
  String get id => 'dlna';

  @override
  Stream<CastEvent> get events => _events.stream;

  @override
  List<CastDevice> get devices => _manager.devices.map(_toCastDevice).toList(growable: false);

  @override
  Future<void> startDiscovery() async {
    if (_closed || _started) {
      return;
    }
    _started = true;
    _soap = SoapClient(transport: _transport);
    _installLogBridge();
    _added = _manager.deviceAdded.listen((device) {
      _events.add(DeviceFound(_toCastDevice(device)));
    });
    _removed = _manager.deviceRemoved.listen((udn) {
      _events.add(DeviceLost(udn));
    });
    _errors = _manager.errors.listen((failure) {
      // A description that cannot be fetched or parsed is not a
      // castable device; report the fault on the event stream where a
      // host can log or ignore it.
      _events.add(CastFault(deviceId: failure.usn, message: 'device description failed', error: failure.error));
    });
    await _manager.start();
  }

  @override
  Future<void> dispose() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _added?.cancel();
    await _removed?.cancel();
    await _errors?.cancel();
    await _manager.dispose();
    // Only the transport this backend created is its to close; a
    // caller-supplied one brings its own lifecycle.
    _ownedTransport?.close();
    await _ownedMediaServer?.stop();
    await _events.close();
  }

  @override
  Future<void> setMedia(CastDevice device, CastMedia media) async {
    final playUrl = await _playableUri(device, media);
    await _call(
      device,
      (service) => SoapRequestBuilder.setUri(
        service: service,
        url: playUrl,
        didl: DidlLite.build(media, resourceUrl: playUrl),
      ),
    );
  }

  /// Works out the URL the renderer should fetch for [media].
  ///
  /// Two Phase 4/5 steps happen here, both failure-tolerant to the
  /// degree the protocol allows: a local file is rewritten through the
  /// media server (a TV cannot read this machine's filesystem), and the
  /// device's declared sink capabilities veto formats it says it cannot
  /// play. An unreachable capability probe degrades to "unknown" — the
  /// cast is still attempted, because a TV that says less is not a TV
  /// that plays nothing.
  Future<String> _playableUri(CastDevice device, CastMedia media) async {
    final capability = await _capabilityOf(device);
    final source = Uri.parse(media.url);
    final served = await _maybeServe(device, source, media.headers);
    final uri = served ?? source;
    final mimeType = media.mimeType ?? MimeType.forPath(media.url);

    final DlnaMediaSelection selection;
    try {
      selection = const DlnaMediaSelector().select(
        media: DlnaMedia(
          id: device.id,
          title: media.title,
          mediaType: DlnaMediaType.fromMimeType(mimeType),
          sourceUri: source,
          resources: <DlnaMediaResource>[
            DlnaMediaResource(uri: uri, mimeType: mimeType, supportsByteRange: served != null),
          ],
        ),
        capability: capability,
      );
    } on DlnaUnsupportedMediaException catch (error) {
      throw CastException(error.message, deviceId: device.id, cause: error);
    }
    if (selection.requiresTranscoding) {
      _log.warning(
        'device needs a converted stream; sending as-is',
        fields: <String, Object?>{'device': device.id, 'reasons': selection.reasons.join(' | ')},
      );
    }
    return selection.resource.uri.toString();
  }

  /// The device's sink capability, queried once per device.
  Future<DlnaMediaCapability> _capabilityOf(CastDevice device) async {
    final cached = _capabilities[device.id];
    if (cached != null) {
      return cached;
    }
    final connectionManager = _manager.device(device.id)?.connectionManager;
    if (connectionManager == null) {
      return const DlnaMediaCapability.unknown();
    }
    final capability = await DlnaCapabilityResolver(client: _soap).resolve(connectionManager);
    _capabilities[device.id] = capability;
    return capability;
  }

  /// Registers media with the media server, returning the LAN URL the
  /// TV fetches:
  ///
  /// - a local file is served from disk;
  /// - a remote URL that carries request headers (Referer/Cookie/UA —
  ///   the token-gated kind a TV cannot fetch) is proxied, with HLS
  ///   playlists rewritten so segment fetches keep the headers;
  /// - a plain remote URL passes through untouched.
  Future<Uri?> _maybeServe(CastDevice device, Uri source, Map<String, String> upstreamHeaders) async {
    final file = _localFileOf(source.toString());
    final server = _mediaServer;
    if (!server.isRunning) {
      await server.start();
    }
    // A previous cast's registration is dead weight the moment this
    // one replaces it; dropping it keeps the registry honest.
    final previous = _served.remove(device.id);
    if (previous != null) {
      server.unregister(previous);
    }

    if (file != null) {
      final url = await server.registerFile(file);
      _served[device.id] = url;
      return url;
    }
    if (upstreamHeaders.isEmpty) {
      return null;
    }
    final isPlaylist = source.path.toLowerCase().endsWith('.m3u8');
    final url = await server.registerRemote(source, upstreamHeaders: upstreamHeaders, isPlaylist: isPlaylist);
    _served[device.id] = url;
    return url;
  }

  /// A local file reference, when [url] names one on this machine.
  ///
  /// `file://` URIs, Windows drive paths (which `Uri.parse` reports as
  /// a one-letter scheme), UNC paths and POSIX absolute paths all
  /// qualify; anything with an http(s) or other remote scheme does not.
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

  @override
  Future<void> play(CastDevice device) => _call(device, (service) => SoapRequestBuilder.play(service: service));

  @override
  Future<void> pause(CastDevice device) => _call(device, (service) => SoapRequestBuilder.pause(service: service));

  @override
  Future<void> stop(CastDevice device) => _call(device, (service) => SoapRequestBuilder.stop(service: service));

  @override
  Future<void> seek(CastDevice device, Duration position) =>
      _call(device, (service) => SoapRequestBuilder.seek(service: service, target: position));

  /// Reads position and duration in one `GetPositionInfo`.
  ///
  /// A device that has stopped answering yields
  /// [CastPosition.unknown] instead of throwing: a controller's poll
  /// loop must be able to gray its progress ring out, not crash a UI
  /// widget over a TV that just left the Wi-Fi.
  @override
  Future<CastPosition> position(CastDevice device) async {
    final service = _transportOf(device);
    try {
      final result = await _soap.invoke(service: service, action: 'GetPositionInfo');
      final relTime = DurationCodec.tryParse(result.argument('RelTime'));
      final trackDuration = DurationCodec.tryParse(result.argument('TrackDuration'));
      if (relTime == null && trackDuration == null) {
        return const CastPosition.unknown();
      }
      return CastPosition(position: relTime ?? Duration.zero, duration: trackDuration ?? Duration.zero);
    } on Object catch (error) {
      _log.warning('position poll failed', error: error, fields: <String, Object?>{'device': device.id});
      return const CastPosition.unknown();
    }
  }

  @override
  Future<void> setVolume(CastDevice device, int percent) async {
    final rendering = _deviceOf(device)?.renderingControl;
    if (rendering == null) {
      throw CastException('device exposes no RenderingControl service', deviceId: device.id);
    }
    // UPnP defines the volume channel as 0..100; out-of-range values are a
    // device fault on most firmwares rather than a clamp.
    final desired = percent.clamp(0, 100);
    await _invoke(device, rendering, SoapRequestBuilder.setVolume(service: rendering, desiredVolume: desired));
  }

  DlnaDevice? _deviceOf(CastDevice device) => _manager.device(device.id);

  DlnaService _transportOf(CastDevice device) {
    final service = _deviceOf(device)?.avTransport;
    if (service == null) {
      throw CastException('device has no AVTransport control URL', deviceId: device.id);
    }
    return service;
  }

  Future<void> _call(CastDevice device, SoapRequest Function(DlnaService service) build) async {
    final service = _transportOf(device);
    await _invoke(device, service, build(service));
  }

  Future<void> _invoke(CastDevice device, DlnaService service, SoapRequest request) async {
    if (_closed) {
      throw const CastException('backend is disposed');
    }

    _log.debug('control call', fields: <String, Object?>{'device': device.id, 'action': request.action});

    try {
      await _soap.invokeWithRequest(service: service, request: request);
    } on DlnaUpnpException catch (error) {
      _log.warning(
        'device refused action',
        fields: <String, Object?>{'device': device.id, 'action': request.action, 'code': error.code.rawValue},
      );
      throw CastException(
        'device refused ${request.action}: ${error.description ?? "UPnP error"} (UPnP code ${error.code.rawValue})',
        deviceId: device.id,
        cause: error,
      );
    } on DlnaException catch (error) {
      _log.warning('control request failed', error: error, fields: <String, Object?>{'device': device.id});
      throw CastException('control request failed', deviceId: device.id, cause: error);
    }
  }

  CastDevice _toCastDevice(DlnaDevice device) {
    return CastDevice.of(
      id: device.udn,
      name: device.friendlyName,
      backendId: id,
      typeName: device.avTransport?.serviceType,
      manufacturer: device.manufacturer,
      modelName: device.modelName,
      serviceEndpoints: <String, String>{
        for (final service in device.services) service.name: service.controlUrl.toString(),
      },
    );
  }
}
