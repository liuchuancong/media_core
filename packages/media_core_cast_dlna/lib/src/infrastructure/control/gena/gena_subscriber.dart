import 'dart:async';
import 'dart:io';

import 'package:media_core_cast_dlna/src/domain/entities/dlna_service.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/gena/gena_message_parser.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/description_http_fetcher.dart';
import 'package:media_core_cast_dlna/src/logging/dlna_log.dart';

/// The answer a GENA transport produced.
final class GenaHttpResponse {
  /// Creates a response.
  const GenaHttpResponse({required this.statusCode, required Map<String, String> headers}) : _headers = headers;

  /// The HTTP status code.
  final int statusCode;

  final Map<String, String> _headers;

  /// Case-insensitive header lookup (SID, TIMEOUT, ...).
  String? header(String name) => _headers[name.toLowerCase()];
}

/// Performs the GENA control verbs (`SUBSCRIBE`, `UNSUBSCRIBE`) that
/// ordinary HTTP clients do not expose as first-class methods.
abstract interface class GenaTransport {
  /// Sends [method] with [headers]; the response body is irrelevant to
  /// GENA control and discarded by implementations.
  Future<GenaHttpResponse> request(String method, Uri url, Map<String, String> headers);
}

/// [GenaTransport] over `dart:io HttpClient`.
final class HttpGenaTransport implements GenaTransport {
  /// Creates a transport.
  HttpGenaTransport({HttpClient? client, Duration timeout = const Duration(seconds: 8)})
    : _client = client ?? HttpClient(),
      _timeout = timeout;

  final HttpClient _client;
  final Duration _timeout;

  @override
  Future<GenaHttpResponse> request(String method, Uri url, Map<String, String> headers) async {
    final request = await _client.openUrl(method, url).timeout(_timeout);
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(_timeout);
    await readBoundedBody(response, timeout: _timeout);
    final flat = <String, String>{':status': '${response.statusCode}'};
    response.headers.forEach((name, values) {
      flat[name.toLowerCase()] = values.first;
    });
    return GenaHttpResponse(statusCode: response.statusCode, headers: flat);
  }

  /// Closes pooled sockets.
  void close() => _client.close(force: true);
}

/// An active GENA subscription (§14.3).
final class GenaSubscription {
  /// Creates a subscription.
  const GenaSubscription({required this.sid, required this.callbackUrl, required this.expiresAt});

  /// The device-assigned subscription id.
  final String sid;

  /// The callback URL the device notifies.
  final Uri callbackUrl;

  /// When the subscription lapses without renewal.
  final DateTime expiresAt;

  /// Whether the subscription has already lapsed.
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Maintains one GENA subscription for one service (§14).
///
/// The lifecycle: `SUBSCRIBE` with a CALLBACK header, renewals at half
/// the granted lifetime (§14.6), and `UNSUBSCRIBE` on disposal. Renewal
/// failures retry with a short backoff; after three consecutive
/// failures the subscriber marks itself failed and reports through
/// its onFailed callback — the session keeps running on its polling fallback
/// (§14.7) rather than fighting a device that stopped eventing.
///
/// Incoming notifications are verified against the subscription's SID
/// and deduplicated by SEQ (§14.4, §22.4) before reaching the
/// onNotification callback.
final class GenaSubscriber {
  /// Creates a subscriber for [service]'s `eventSubURL`.
  ///
  /// [callbackUrl] must be a registered route of a running
  /// `GenaCallbackServer`. [now] is injectable for tests.
  GenaSubscriber({
    required GenaTransport transport,
    required this.service,
    required this.callbackUrl,
    required void Function(GenaNotification notification) onNotification,
    void Function(GenaSubscriber subscriber)? onFailed,
    this.lifetime = const Duration(seconds: 1800),
    DateTime Function()? now,
  }) : _transport = transport,
       _onNotification = onNotification,
       _onFailed = onFailed,
       _now = now ?? DateTime.now;

  /// The service being subscribed to.
  final DlnaService service;

  /// The callback URL for this subscription.
  final Uri callbackUrl;

  /// The lifetime requested from the device.
  final Duration lifetime;

  final GenaTransport _transport;
  final void Function(GenaNotification notification) _onNotification;
  final void Function(GenaSubscriber subscriber)? _onFailed;
  final DateTime Function() _now;

  GenaSubscription? _subscription;
  Timer? _renewal;
  int _renewFailures = 0;
  int _lastSeq = -1;
  bool _failed = false;
  bool _disposed = false;

  /// The active subscription, when one is established.
  GenaSubscription? get subscription => _subscription;

  /// Whether the subscription is established and not failed.
  bool get isActive => _subscription != null && !_failed && !_subscription!.isExpired;

  /// Whether renewals failed often enough that the fallback took over.
  bool get isFailed => _failed;

  /// Establishes the subscription.
  ///
  /// Throws [DlnaSubscriptionException] when the service exposes no
  /// eventSubURL or the device refuses; callers treat that as "use the
  /// polling fallback", never as a session failure. A failed attempt
  /// marks the subscriber failed ([isFailed]) — its eventing is done.
  Future<void> subscribe() async {
    if (_disposed) {
      throw const DlnaSubscriptionException('subscriber is disposed');
    }
    final url = service.eventSubUrl;
    if (url == null) {
      _failed = true;
      throw const DlnaSubscriptionException('service exposes no eventSubURL');
    }
    final GenaHttpResponse response;
    try {
      response = await _transport.request('SUBSCRIBE', url, <String, String>{
        'CALLBACK': '<$callbackUrl>',
        'NT': 'upnp:event',
        'TIMEOUT': 'Second-${lifetime.inSeconds}',
      });
    } on Object catch (error) {
      _failed = true;
      throw DlnaSubscriptionException('SUBSCRIBE could not be sent', cause: error);
    }
    if (response.statusCode != 200) {
      _failed = true;
      throw DlnaSubscriptionException('SUBSCRIBE answered ${response.statusCode}');
    }
    final sid = response.header('sid');
    if (sid == null || sid.isEmpty) {
      _failed = true;
      throw const DlnaSubscriptionException('SUBSCRIBE answered without a SID');
    }
    final granted = _parseTimeout(response.header('timeout')) ?? lifetime;
    _subscription = GenaSubscription(sid: sid, callbackUrl: callbackUrl, expiresAt: _now().add(granted));
    DlnaLog.info(
      DlnaLogCategory.gena,
      'subscribed',
      fields: <String, Object?>{'service': service.serviceType, 'lifetime': granted.inSeconds},
    );
    _scheduleRenewal(granted);
  }

  /// Feeds one decoded notification through SID verification and SEQ
  /// deduplication; only fresh events reach the onNotification callback.
  void handle(GenaNotification notification) {
    final subscription = _subscription;
    if (_disposed || subscription == null || _failed) {
      return;
    }
    if (notification.sid != subscription.sid) {
      return;
    }
    if (notification.seq <= _lastSeq) {
      return;
    }
    _lastSeq = notification.seq;
    _onNotification(notification);
  }

  /// Renews are scheduled at half the granted lifetime, so one failed
  /// renewal still leaves a full lifetime to recover in.
  void _scheduleRenewal(Duration granted) {
    _renewal?.cancel();
    final delay = granted ~/ 2;
    if (delay <= Duration.zero) {
      return;
    }
    _renewal = Timer(delay, () => unawaited(_renew(granted)));
  }

  Future<void> _renew(Duration previousGrant) async {
    if (_disposed || _failed || _subscription == null) {
      return;
    }
    final url = service.eventSubUrl;
    if (url == null) {
      return;
    }
    try {
      final response = await _transport.request('SUBSCRIBE', url, <String, String>{
        'SID': _subscription!.sid,
        'TIMEOUT': 'Second-${lifetime.inSeconds}',
      });
      if (response.statusCode != 200) {
        throw DlnaSubscriptionException('renewal answered ${response.statusCode}');
      }
      _renewFailures = 0;
      final granted = _parseTimeout(response.header('timeout')) ?? lifetime;
      _subscription = GenaSubscription(
        sid: _subscription!.sid,
        callbackUrl: callbackUrl,
        expiresAt: _now().add(granted),
      );
      _scheduleRenewal(granted);
    } on Object {
      _renewFailures++;
      if (_renewFailures >= 3) {
        // §14.7: give up gracefully; the polling fallback carries on.
        _failed = true;
        _renewal?.cancel();
        _renewal = null;
        DlnaLog.warning(
          DlnaLogCategory.gena,
          'renewals exhausted; falling back to polling',
          fields: <String, Object?>{'service': service.serviceType, 'failures': _renewFailures},
        );
        _onFailed?.call(this);
        return;
      }
      DlnaLog.warning(
        DlnaLogCategory.gena,
        'renewal failed; retrying',
        fields: <String, Object?>{'service': service.serviceType, 'failures': _renewFailures},
      );
      _renewal = Timer(previousGrant ~/ 4 * _renewFailures, () => unawaited(_renew(previousGrant)));
    }
  }

  /// Cancels renewal scheduling and tells the device to drop the
  /// subscription (best effort — a device that has gone offline simply
  /// never answers, which is fine).
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _renewal?.cancel();
    _renewal = null;
    final subscription = _subscription;
    final url = service.eventSubUrl;
    if (subscription != null && url != null && !_failed) {
      try {
        await _transport.request('UNSUBSCRIBE', url, <String, String>{'SID': subscription.sid});
        DlnaLog.info(DlnaLogCategory.gena, 'unsubscribed', fields: <String, Object?>{'service': service.serviceType});
      } on Object {
        // Best effort: the device may already be gone.
      }
    }
    _subscription = null;
  }

  /// Parses a `Second-1800` TIMEOUT value; `Second-infinite` and junk
  /// yield null (the requested lifetime is used instead).
  static Duration? _parseTimeout(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || !value.startsWith('second-')) {
      return null;
    }
    final seconds = int.tryParse(value.substring(7).trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
