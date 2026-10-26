import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/request_id.dart';
import 'package:media_core/src/identity/source_id.dart';
import 'package:media_core/src/source/descriptor/source_headers.dart';
import 'package:media_core/src/source/types/source_type.dart';

part 'source_request.g.dart';

/// Represents a request to load a media source.
///
/// [SourceRequest] is the input model passed to
/// source resolving and playback preparation.
///
/// Responsibilities:
///
/// - identify requested source
/// - provide request options
/// - carry loading preferences
///
/// It does not:
///
/// - resolve URLs
/// - open network connections
/// - create players
///
/// Those belong to:
///
/// - SourceResolver
/// - PlayerSession
/// - PlayerAdapter
abstract class SourceRequest implements Built<SourceRequest, SourceRequestBuilder> {
  /// Builds SourceRequest from a [updates] callback — the codegen entry.
  factory SourceRequest([void Function(SourceRequestBuilder)? updates]) = _$SourceRequest;

  /// Creates a source request.
  factory SourceRequest.of({
    required RequestId id,
    SourceId? sourceId,
    Uri? uri,
    SourceType type = SourceType.unknown,
    SourceHeaders? headers,
    bool live = false,
    bool lowLatency = false,
    bool enableCache = true,
    bool allowFallback = true,
    Duration? timeout,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return SourceRequest(
      (builder) => builder
        ..id = id
        ..sourceId = sourceId
        ..uri = uri
        ..type = type
        ..headers = headers
        ..live = live
        ..lowLatency = lowLatency
        ..enableCache = enableCache
        ..allowFallback = allowFallback
        ..timeout = timeout
        ..attributes = attributes,
    );
  }

  /// Creates a request from URI.
  factory SourceRequest.fromUri(Uri uri) {
    return SourceRequest.of(id: RequestId.generate(), uri: uri);
  }

  SourceRequest._();

  /// A request is on-demand, cached, fallback-allowed and unadorned until the
  /// caller says otherwise; its type stays unknown until something resolves it.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(SourceRequestBuilder builder) => builder
    ..type = SourceType.unknown
    ..live = false
    ..lowLatency = false
    ..enableCache = true
    ..allowFallback = true
    ..attributes = const <String, Object?>{};

  /// Request identifier.
  RequestId get id;

  /// Target source identifier.
  SourceId? get sourceId;

  /// Source URI.
  Uri? get uri;

  /// Preferred source type.
  SourceType get type;

  /// Additional request headers.
  SourceHeaders? get headers;

  /// Whether this request is for live playback.
  bool get live;

  /// Whether to prefer low latency.
  bool get lowLatency;

  /// Whether caching should be enabled.
  bool get enableCache;

  /// Whether network fallback is allowed.
  bool get allowFallback;

  /// Optional timeout.
  Duration? get timeout;

  /// Custom request attributes.
  Map<String, Object?> get attributes;
}

/// Extensions for [SourceRequest].
extension SourceRequestExtension on SourceRequest {
  /// Whether request has a URI.
  bool get hasUri {
    return uri != null;
  }

  /// Whether request has source id.
  bool get hasSourceId {
    return sourceId != null;
  }

  /// Whether request can be resolved.
  bool get resolvable {
    return hasUri || hasSourceId;
  }

  /// Whether this is a live request.
  bool get isLive {
    return live;
  }

  /// Creates request with attribute.
  SourceRequest putAttribute(String key, Object? value) {
    return rebuild((builder) => builder..attributes = <String, Object?>{...attributes, key: value});
  }
}
