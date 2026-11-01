import 'package:media_core_cast_dlna/src/domain/enums/upnp_error_code.dart';

/// Base class of every error this package raises.
///
/// The hierarchy exists so a caller can tell the five failure worlds
/// apart without string matching: discovery could not run, a document
/// was unreadable, the network broke, the transport failed, or the
/// device itself refused. Collapsing them into one "cast failed" is
/// exactly what this package must not do.
sealed class DlnaException implements Exception {
  /// Creates an exception.
  const DlnaException(this.message, {this.cause});

  /// Human-readable reason.
  final String message;

  /// Underlying error, when there was one.
  final Object? cause;

  /// The family name used in [toString]; every subclass names itself
  /// here so logs read as the concrete type without relying on
  /// `runtimeType`.
  String get label => 'DlnaException';

  @override
  String toString() => '$label: $message';
}

/// Discovery itself could not run — the socket could not be bound, the
/// feed failed irrecoverably.
final class DlnaDiscoveryException extends DlnaException {
  /// Creates an exception.
  const DlnaDiscoveryException(super.message, {super.cause});

  @override
  String get label => 'DlnaDiscoveryException';
}

/// A device description document was unfetchable, not XML, or missing
/// the identity a device needs (UDN).
final class DlnaDeviceDescriptionException extends DlnaException {
  /// Creates an exception.
  const DlnaDeviceDescriptionException(super.message, {super.cause});

  @override
  String get label => 'DlnaDeviceDescriptionException';
}

/// A service description (SCPD) was unfetchable or unparseable.
final class DlnaServiceDescriptionException extends DlnaException {
  /// Creates an exception.
  const DlnaServiceDescriptionException(super.message, {super.cause});

  @override
  String get label => 'DlnaServiceDescriptionException';
}

/// A network-level failure while talking to a device: the connection
/// refused, reset, or never established.
class DlnaNetworkException extends DlnaException {
  /// Creates an exception.
  const DlnaNetworkException(super.message, {super.cause});

  @override
  String get label => 'DlnaNetworkException';

  /// Whether a bounded retry makes sense. Network faults do; a device
  /// that answered with an error does not, and subclasses below freeze
  /// this accordingly.
  bool get retriable => true;
}

/// A device answer did not arrive inside the time budget.
class DlnaTimeoutException extends DlnaNetworkException {
  /// Creates an exception.
  const DlnaTimeoutException(super.message, {super.cause});

  @override
  String get label => 'DlnaTimeoutException';
}

/// The HTTP transport of a control exchange failed: a non-2xx answer
/// that carried no SOAP fault, or a body that violated the transport
/// bounds.
final class DlnaSoapException extends DlnaException {
  /// Creates an exception.
  const DlnaSoapException(super.message, {super.cause});

  @override
  String get label => 'DlnaSoapException';

  /// Whether a bounded retry makes sense; transport-level failures may
  /// be transient, so they default to yes.
  bool get retriable => true;
}

/// The device answered a control request with a UPnP error.
///
/// The TV is alive and refusing — this is never a reason to retry the
/// identical request.
class DlnaUpnpException extends DlnaException {
  /// Creates an exception.
  const DlnaUpnpException(super.message, {required this.code, this.description, super.cause});

  /// The classified UPnP error code.
  final UpnpErrorCode code;

  /// The device's own error description, when it sent one.
  final String? description;

  @override
  String get label => 'DlnaUpnpException';

  /// UPnP errors are device verdicts, not network hiccups.
  bool get retriable => false;
}

/// The device does not implement the requested action
/// (UPnP 401 Invalid Action, or a missing entry in its SCPD).
final class DlnaUnsupportedActionException extends DlnaUpnpException {
  /// Creates an exception.
  const DlnaUnsupportedActionException({super.description, super.cause})
    : super('device does not support this action', code: UpnpErrorCode.invalidAction);

  @override
  String get label => 'DlnaUnsupportedActionException';
}

/// No available resource of a media item fits the device's declared
/// capabilities.
///
/// This is a verdict, not a network failure: retrying cannot help. The
/// [reasons] carry the per-resource rejection trace so a host can say
/// "this TV plays MP4/H.264, your file is WebM/VP9" instead of "cast
/// failed".
final class DlnaUnsupportedMediaException extends DlnaException {
  /// Creates an exception.
  const DlnaUnsupportedMediaException(super.message, {required this.reasons, super.cause});

  /// Why each candidate resource was rejected.
  final List<String> reasons;

  @override
  String get label => 'DlnaUnsupportedMediaException';
}

/// A session-level failure: a command was dropped (a stop cancelled
/// it), the session was used after disposal, or the session ended under
/// a command's feet.
final class DlnaSessionException extends DlnaException {
  /// Creates an exception.
  const DlnaSessionException(super.message, {super.cause});

  @override
  String get label => 'DlnaSessionException';
}

/// A GENA subscription could not be established, renewed, or torn down.
///
/// A failed subscription is not a session failure: the polling fallback
/// (§14.7, §19.1) keeps state flowing, just with more requests on the
/// wire and slower updates.
final class DlnaSubscriptionException extends DlnaException {
  /// Creates an exception.
  const DlnaSubscriptionException(super.message, {super.cause});

  @override
  String get label => 'DlnaSubscriptionException';
}
