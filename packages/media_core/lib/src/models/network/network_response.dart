import 'package:built_value/built_value.dart';
import 'package:media_core/src/network/monitor/network_manager.dart';

part 'network_response.g.dart';

/// Represents a network response.
///
/// A [NetworkResponse] contains the result returned
/// from a network operation.
///
/// Responsibilities:
///
/// - store response status
/// - store response data
/// - store response headers
/// - describe request outcome
///
/// It does not:
///
/// - perform network operations
/// - decode business models
/// - handle retries
///
/// Those belong to:
///
/// - [NetworkManager]
/// - higher-level operation layer
abstract class NetworkResponse implements Built<NetworkResponse, NetworkResponseBuilder> {
  /// Builds a response from a [updates] callback — the codegen entry.
  factory NetworkResponse([void Function(NetworkResponseBuilder)? updates]) = _$NetworkResponse;

  /// Creates a network response.
  factory NetworkResponse.of({
    int? statusCode,
    Object? data,
    Map<String, String>? headers,
    Duration? duration,
    bool fromCache = false,
    DateTime? timestamp,
  }) {
    return NetworkResponse(
      (builder) => builder
        ..statusCode = statusCode
        ..data = data
        ..headers = headers
        ..duration = duration
        ..fromCache = fromCache
        ..timestamp = timestamp,
    );
  }

  NetworkResponse._();

  /// Creates an empty response.
  factory NetworkResponse.empty() => NetworkResponse.of();

  /// An unrecorded response came from no cache; status, data, headers
  /// and duration are genuinely absent until a transport fills them.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(NetworkResponseBuilder builder) => builder..fromCache = false;

  /// HTTP-like status code.
  ///
  /// May be unavailable for custom transports.
  int? get statusCode;

  /// Response body.
  Object? get data;

  /// Response headers.
  Map<String, String>? get headers;

  /// Request duration.
  Duration? get duration;

  /// Whether response came from cache.
  bool get fromCache;

  /// Request timestamp.
  DateTime? get timestamp;
}

/// Extension helpers for [NetworkResponse].
extension NetworkResponseExtension on NetworkResponse {
  /// Whether response has a successful status code.
  bool get isSuccess {
    if (statusCode == null) {
      return false;
    }

    return statusCode! >= 200 && statusCode! < 300;
  }

  /// Whether response contains data.
  bool get hasData {
    return data != null;
  }

  /// Whether response has headers.
  bool get hasHeaders {
    return headers != null && headers!.isNotEmpty;
  }
}
