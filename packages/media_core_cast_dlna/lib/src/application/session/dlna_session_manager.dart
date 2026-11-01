import 'package:media_core_cast_dlna/src/application/playback/dlna_playback_monitor.dart';
import 'package:media_core_cast_dlna/src/application/session/dlna_recovery_policy.dart';
import 'package:media_core_cast_dlna/src/application/session/dlna_session.dart';
import 'package:media_core_cast_dlna/src/domain/contracts/soap_transport.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_device.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/infrastructure/compatibility/device_compatibility.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/gena/gena_callback_server.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/gena/gena_subscriber.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/http_soap_transport.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_client.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/description_http_fetcher.dart';

/// Creates, holds and tears down cast sessions (Phase 6 deliverable).
///
/// One device can host several sessions over time, but the manager
/// keeps at most one *active* session per device: connecting to a
/// device that already has one returns that session instead of
/// stacking a second command queue on the same renderer (§8.3, §23.2).
///
/// When [enableGena] is on (the default), each session's AVTransport
/// is also subscribed through a shared [GenaCallbackServer] (§14) — a
/// device that evented state pushes it here first, and the session's
/// polling monitor stays as the fallback every device understands.
final class DlnaSessionManager {
  /// Creates a manager.
  ///
  /// [transport] is injectable for tests; the default owns an
  /// [HttpSoapTransport] that [dispose] closes. [fetchScpd] loads
  /// AVTransport SCPDs during session connect; the default fetches over
  /// HTTP. [callbackServer] and [genaTransport] are the GENA seams; the
  /// defaults are created lazily and owned.
  DlnaSessionManager({
    SoapTransport? transport,
    this.timeout = const Duration(seconds: 8),
    this.monitorOptions = const DlnaPlaybackMonitorOptions(),
    DescriptionFetcher? fetchScpd,
    this.enableGena = true,
    this.recoveryPolicy = const DlnaRecoveryPolicy(),
    DeviceCompatibilityRegistry? compatibility,
    GenaCallbackServer? callbackServer,
    GenaTransport? genaTransport,
  }) {
    if (transport != null) {
      _transport = transport;
    } else {
      final http = HttpSoapTransport(timeout: timeout);
      _ownedTransport = http;
      _transport = http;
    }
    _client = SoapClient(transport: _transport, timeout: timeout);
    _fetchScpd = fetchScpd ?? HttpDescriptionFetcher(timeout: timeout).call;
    _ownedFetcher = fetchScpd == null ? HttpDescriptionFetcher(timeout: timeout) : null;
    _providedCallbackServer = callbackServer;
    compatibilityRegistry = compatibility ?? DeviceCompatibilityRegistry();
    if (genaTransport != null) {
      _genaTransport = genaTransport;
    } else {
      final http = HttpGenaTransport(timeout: timeout);
      _ownedGenaTransport = http;
      _genaTransport = http;
    }
  }

  /// The SOAP time budget, also applied to SCPD loads and GENA control.
  final Duration timeout;

  /// The polling cadence new sessions start with.
  final DlnaPlaybackMonitorOptions monitorOptions;

  /// Whether AVTransport eventing is attempted for new sessions.
  final bool enableGena;

  /// The recovery policy new sessions start with (§20.4).
  final DlnaRecoveryPolicy recoveryPolicy;

  /// Resolves the vendor-quirk profile each session runs under (§9).
  late final DeviceCompatibilityRegistry compatibilityRegistry;

  late final SoapTransport _transport;
  HttpSoapTransport? _ownedTransport;
  late final SoapClient _client;
  late final DescriptionFetcher _fetchScpd;
  HttpDescriptionFetcher? _ownedFetcher;
  GenaCallbackServer? _providedCallbackServer;
  GenaCallbackServer? _ownedCallbackServer;
  late final GenaTransport _genaTransport;
  HttpGenaTransport? _ownedGenaTransport;

  final Map<String, DlnaSessionController> _sessions = <String, DlnaSessionController>{};
  final Map<String, Uri> _genaCallbacks = <String, Uri>{};
  bool _disposed = false;

  GenaCallbackServer get _callbackServer => _providedCallbackServer ?? (_ownedCallbackServer ??= GenaCallbackServer());

  /// The active sessions, in creation order.
  List<DlnaSession> get sessions => List<DlnaSession>.unmodifiable(_sessions.values);

  /// The active session for [device], when one exists.
  DlnaSession? sessionFor(DlnaDevice device) => _sessions[device.udn];

  /// Connects to [device], or returns its existing active session.
  Future<DlnaSession> connect(DlnaDevice device) async {
    if (_disposed) {
      throw const DlnaSessionException('session manager is disposed');
    }
    final avTransport = device.avTransport;
    if (avTransport == null) {
      throw const DlnaSessionException('device exposes no AVTransport service');
    }
    final existing = _sessions[device.udn];
    if (existing != null) {
      return existing;
    }
    final session = DlnaSessionController(
      device: device,
      client: _client,
      monitorOptions: monitorOptions,
      fetchScpd: _fetchScpd,
      recoveryPolicy: recoveryPolicy,
      profile: compatibilityRegistry.profileFor(device),
      genaFactory: enableGena ? _buildGenaSubscriber : null,
    );
    try {
      await session.connect();
    } on Object {
      await session.dispose();
      rethrow;
    }
    _sessions[device.udn] = session;
    return session;
  }

  /// Builds a fresh GENA subscriber for [device] against a new callback
  /// route. Used both when a session connects and when its recovery
  /// re-arms eventing (§20.4) — each re-arm drops the device's previous
  /// route first.
  Future<GenaSubscriber> _buildGenaSubscriber(DlnaDevice device) async {
    final server = _callbackServer;
    if (!server.isRunning) {
      await server.start();
    }
    final avTransport = device.avTransport;
    if (avTransport?.eventSubUrl == null) {
      throw const DlnaSubscriptionException('device exposes no eventSubURL');
    }
    final previous = _genaCallbacks.remove(device.udn);
    if (previous != null) {
      server.unregisterHandler(previous);
    }
    // The route feeds the subscriber — not the session directly — so
    // every notification passes the subscriber's SID verification and
    // SEQ deduplication (§22.4) before merging.
    GenaSubscriber? subscriber;
    final callbackUrl = server.registerHandler((notification) => subscriber?.handle(notification));
    _genaCallbacks[device.udn] = callbackUrl;
    return subscriber = GenaSubscriber(
      transport: _genaTransport,
      service: avTransport!,
      callbackUrl: callbackUrl,
      onNotification: (notification) => _sessions[device.udn]?.handleGenaNotification(notification),
      onFailed: (_) {
        // §14.7: renewals exhausted — the session's polling fallback is
        // already running; nothing else to do here.
      },
    );
  }

  /// Ends one session and forgets it.
  Future<void> disconnect(DlnaSession session) async {
    if (session is! DlnaSessionController) {
      throw DlnaSessionException('session was not created by this manager: ${session.id}');
    }
    if (_sessions.remove(session.device.udn) != null) {
      await session.dispose();
    }
    final callback = _genaCallbacks.remove(session.device.udn);
    if (callback != null) {
      _providedCallbackServer?.unregisterHandler(callback);
      _ownedCallbackServer?.unregisterHandler(callback);
    }
  }

  /// Disconnects every session and releases the owned transports and
  /// the owned callback server.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final session in _sessions.values) {
      await session.dispose();
    }
    _sessions.clear();
    _genaCallbacks.clear();
    _ownedFetcher?.close();
    _ownedTransport?.close();
    _ownedGenaTransport?.close();
    await _ownedCallbackServer?.stop();
  }
}
