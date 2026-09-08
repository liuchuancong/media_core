import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_headers.freezed.dart';

/// Represents headers attached to a media source.
///
/// [SourceHeaders] stores additional metadata
/// required when accessing a media source.
///
/// Common examples:
///
/// - User-Agent
/// - Referer
/// - Authorization
/// - Custom CDN headers
///
/// Responsibilities:
///
/// - provide immutable header values
/// - store request metadata
///
/// It does not:
///
/// - send requests
/// - manage cookies
/// - perform authentication
///
/// Those belong to:
///
/// - network layer
/// - util/cookie_utils.dart
@freezed
abstract class SourceHeaders with _$SourceHeaders {
  /// Creates source headers.
  const factory SourceHeaders({
    /// Header key-value pairs.
    @Default({}) Map<String, String> values,

    /// Whether headers should override defaults.
    @Default(false) bool overrideDefaults,
  }) = _SourceHeaders;

  /// Creates empty headers.
  factory SourceHeaders.empty() {
    return const SourceHeaders();
  }
}

/// Extensions for [SourceHeaders].
extension SourceHeadersExtension on SourceHeaders {
  /// Whether no headers exist.
  bool get isEmpty {
    return values.isEmpty;
  }

  /// Whether headers exist.
  bool get isNotEmpty {
    return values.isNotEmpty;
  }

  /// Number of headers.
  int get length {
    return values.length;
  }

  /// Gets a header value.
  String? operator [](String key) {
    return values[key];
  }

  /// Whether a header exists.
  bool contains(String key) {
    return values.containsKey(key);
  }

  /// Creates a new instance with one header added.
  SourceHeaders put(String key, String value) {
    return copyWith(values: {...values, key: value});
  }

  /// Creates a new instance without a header.
  SourceHeaders remove(String key) {
    final result = Map<String, String>.from(values);

    result.remove(key);

    return copyWith(values: result);
  }
}
