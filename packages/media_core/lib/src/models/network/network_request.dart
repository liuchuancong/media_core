import 'package:built_value/built_value.dart';
import 'package:media_core/src/network/monitor/network_manager.dart';
import 'package:media_core/src/source/descriptor/source_headers.dart';

part 'network_request.g.dart';

/// Represents a network request.
///
/// A [NetworkRequest] describes a request that can be
/// executed by a network adapter.
///
/// Responsibilities:
///
/// - describe target URI
/// - describe HTTP method
/// - carry request headers
/// - define timeout/retry hints
///
/// It does not:
///
/// - open connections
/// - perform IO
/// - parse responses
///
/// Those belong to:
///
/// - [NetworkManager]
/// - platform network adapters
abstract class NetworkRequest implements Built<NetworkRequest, NetworkRequestBuilder> {
  /// Builds a request from a [updates] callback — the codegen entry.
  factory NetworkRequest([void Function(NetworkRequestBuilder)? updates]) = _$NetworkRequest;

  /// Creates a network request.
  factory NetworkRequest.of({
    required Uri uri,
    String method = 'GET',
    SourceHeaders? headers,
    Object? body,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    int maxRetries = 0,
    bool cacheable = false,
    Map<String, Object?>? metadata,
  }) {
    return NetworkRequest(
      (builder) => builder
        ..uri = uri
        ..method = method
        ..headers = headers
        ..body = body
        ..connectTimeout = connectTimeout
        ..receiveTimeout = receiveTimeout
        ..maxRetries = maxRetries
        ..cacheable = cacheable
        ..metadata = metadata,
    );
  }

  NetworkRequest._();

  /// A request is a GET with no retries and no caching unless the
  /// caller says otherwise; headers, body, timeouts and metadata stay
  /// absent rather than empty.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(NetworkRequestBuilder builder) => builder
    ..method = 'GET'
    ..maxRetries = 0
    ..cacheable = false;

  /// Target resource URI.
  Uri get uri;

  /// HTTP method.
  String get method;

  /// Request headers.
  SourceHeaders? get headers;

  /// Request body.
  ///
  /// The concrete type is controlled by
  /// the network implementation.
  Object? get body;

  /// Connection timeout.
  Duration? get connectTimeout;

  /// Response timeout.
  Duration? get receiveTimeout;

  /// Maximum retry count.
  int get maxRetries;

  /// Whether this request can use cache.
  bool get cacheable;

  /// Extra request metadata.
  Map<String, Object?>? get metadata;
}
