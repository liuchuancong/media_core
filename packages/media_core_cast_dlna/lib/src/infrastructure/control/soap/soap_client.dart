import 'dart:async';
import 'dart:io';

import 'package:media_core_cast_dlna/src/domain/contracts/soap_transport.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_service.dart';
import 'package:media_core_cast_dlna/src/domain/enums/upnp_error_code.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_fault_parser.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_request_builder.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_response_parser.dart';
import 'package:media_core_cast_dlna/src/logging/dlna_log.dart';

/// The outcome of one executed UPnP action.
final class SoapActionResult {
  /// Creates a result.
  const SoapActionResult({required this.action, required this.statusCode, required this.arguments, required this.body});

  /// The quoted SOAPAction header value that was sent.
  final String action;

  /// HTTP status code.
  final int statusCode;

  /// Output arguments of the response element, by local name.
  final Map<String, String> arguments;

  /// The raw response body.
  final String body;

  /// One output argument by local name, when present.
  String? argument(String name) => arguments[name];
}

/// Executes UPnP actions over a [SoapTransport]: builds the envelope,
/// applies the time budget, and maps every failure onto its
/// [DlnaException] type.
///
/// The mapping is the point: a timeout, a refused connection and a
/// device-side UPnP error are three different worlds (retry / retry
/// later / never retry), and callers downstream of this class must not
/// have to re-derive which one happened from a raw exception.
final class SoapClient {
  /// Creates a client.
  ///
  /// [timeout] budgets one whole exchange; a device that accepts the
  /// request and then stalls answers with [DlnaTimeoutException] rather
  /// than a future that never completes.
  SoapClient({required SoapTransport transport, this.timeout = const Duration(seconds: 8)}) : _transport = transport;

  final SoapTransport _transport;

  /// The per-exchange time budget.
  final Duration timeout;

  /// Invokes [action] on [service] with [arguments].
  ///
  /// When [supportedActions] is provided (from the service's SCPD), an
  /// action the device does not declare is refused locally with
  /// [DlnaUnsupportedActionException] instead of being sent to a device
  /// that will answer 401 anyway.
  Future<SoapActionResult> invoke({
    required DlnaService service,
    required String action,
    Map<String, String> arguments = const <String, String>{},
    Set<String>? supportedActions,
  }) {
    return invokeWithRequest(
      service: service,
      request: SoapRequestBuilder.invoke(service: service, action: action, arguments: arguments),
      supportedActions: supportedActions,
    );
  }

  /// Executes a request built by [SoapRequestBuilder], applying the
  /// same error mapping as [invoke].
  Future<SoapActionResult> invokeWithRequest({
    required DlnaService service,
    required SoapRequest request,
    Set<String>? supportedActions,
  }) async {
    final actionName = _actionNameOf(request.action);
    if (supportedActions != null && actionName != null && !supportedActions.contains(actionName)) {
      throw DlnaUnsupportedActionException(description: '$actionName is not declared by ${service.serviceType}');
    }
    final action = actionName ?? request.action;

    final SoapHttpResponse response;
    try {
      response = await _transport.post(service.controlUrl, request.headers, request.body).timeout(timeout);
    } on TimeoutException catch (error) {
      DlnaLog.warning(
        DlnaLogCategory.soap,
        'action timed out',
        error: error,
        fields: <String, Object?>{'action': action, 'timeout': timeout.inMilliseconds},
      );
      throw DlnaTimeoutException('device did not answer $action within ${timeout.inSeconds}s', cause: error);
    } on SocketException catch (error) {
      DlnaLog.warning(
        DlnaLogCategory.soap,
        'control endpoint unreachable',
        error: error,
        fields: <String, Object?>{'action': action},
      );
      throw DlnaNetworkException('could not reach ${service.controlUrl} for $action', cause: error);
    } on FormatException catch (error) {
      throw DlnaSoapException('transport rejected the $action exchange', cause: error);
    } on Object catch (error) {
      // Transports are pluggable; whatever unexpected error one raises
      // is still a network-world failure to the caller, not a crash.
      throw DlnaNetworkException('control exchange for $action failed', cause: error);
    }

    final fault = SoapFaultParser.parse(response.body);
    if (fault != null) {
      if (fault.code == UpnpErrorCode.invalidAction) {
        throw DlnaUnsupportedActionException(description: fault.errorDescription, cause: fault);
      }
      DlnaLog.warning(
        DlnaLogCategory.soap,
        'device refused action',
        fields: <String, Object?>{'action': action, 'code': fault.code.rawValue},
      );
      throw DlnaUpnpException(
        'device refused $action: ${fault.errorDescription ?? fault.errorCode ?? fault.faultString ?? "unknown"}',
        code: fault.code,
        description: fault.errorDescription,
        cause: fault,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DlnaSoapException('device answered ${response.statusCode} to $action');
    }

    return SoapActionResult(
      action: request.action,
      statusCode: response.statusCode,
      arguments: SoapResponseParser.arguments(response.body),
      body: response.body,
    );
  }

  /// Extracts the bare action name from a quoted SOAPAction header
  /// value (`"urn:...:AVTransport:1#Play"` → `Play`).
  ///
  /// The closing quote is part of the header value; forgetting it makes
  /// every capability lookup miss by one character and refuse actions
  /// the device actually declares.
  static String? _actionNameOf(String quotedAction) {
    final hash = quotedAction.lastIndexOf('#');
    if (hash < 0 || hash + 1 >= quotedAction.length) {
      return null;
    }
    return quotedAction.substring(hash + 1).replaceAll('"', '').trim();
  }
}
