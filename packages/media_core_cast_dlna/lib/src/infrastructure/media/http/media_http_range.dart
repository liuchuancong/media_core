import 'dart:math';

/// A parsed HTTP `Range` header for one media resource.
///
/// Single-segment byte ranges only: that is the whole grammar media
/// renderers use (`bytes=start-end`, `bytes=start-`, `bytes=-suffix`),
/// and a multipart response no TV asks for. The numbers here are
/// **inclusive** on both ends, exactly as the header spells them — the
/// conversion to Dart's exclusive-end slicing happens once, in
/// [sliceStart]/[sliceEnd], so the off-by-one lives in exactly one
/// place.
final class HttpByteRange {
  /// Creates a resolved range.
  const HttpByteRange._(this.start, this.end);

  /// First byte to send (inclusive).
  final int start;

  /// Last byte to send (inclusive).
  final int end;

  /// Number of bytes this range carries.
  int get length => end - start + 1;

  /// The `Content-Range` value for a resource of [size]
  /// (`bytes 0-1023/10485760`).
  String contentRange(int size) => 'bytes $start-$end/$size';

  /// Parses a `Range` header against a resource of [size].
  ///
  /// Returns the absent outcome when there is nothing to honor: no
  /// header, a non-byte unit, or a syntactically broken spec. Returns
  /// the unsatisfiable outcome when the spec is well-formed but the
  /// request cannot be served (416 territory).
  static HttpByteRangeOutcome parse(String? header, int size) {
    final value = header?.trim() ?? '';
    if (!value.toLowerCase().startsWith('bytes=')) {
      return const HttpByteRangeOutcome.absent();
    }
    final spec = value.substring(6).trim();
    // A multipart range is not honored; the whole resource is sent
    // with a 200 instead, which every renderer copes with.
    if (spec.contains(',')) {
      return const HttpByteRangeOutcome.absent();
    }
    final dash = spec.indexOf('-');
    if (dash < 0) {
      return const HttpByteRangeOutcome.absent();
    }
    final startText = spec.substring(0, dash).trim();
    final endText = spec.substring(dash + 1).trim();

    if (startText.isEmpty) {
      // Suffix form: `bytes=-N` asks for the last N bytes.
      final suffix = endText.isEmpty ? null : int.tryParse(endText);
      if (suffix == null || suffix <= 0) {
        return const HttpByteRangeOutcome.unsatisfiable();
      }
      final length = min(suffix, size);
      if (size == 0 || length == 0) {
        return const HttpByteRangeOutcome.unsatisfiable();
      }
      return HttpByteRangeOutcome.satisfied(HttpByteRange._(size - length, size - 1));
    }

    final start = int.tryParse(startText);
    if (start == null || start < 0) {
      return const HttpByteRangeOutcome.absent();
    }
    if (start >= size) {
      return const HttpByteRangeOutcome.unsatisfiable();
    }
    final end = endText.isEmpty ? size - 1 : (int.tryParse(endText) ?? -1);
    if (end < start) {
      return const HttpByteRangeOutcome.absent();
    }
    return HttpByteRangeOutcome.satisfied(HttpByteRange._(start, min(end, size - 1)));
  }
}

/// The result of a range parse: absent (serve everything with 200),
/// satisfied, or unsatisfiable (416).
sealed class HttpByteRangeOutcome {
  const HttpByteRangeOutcome();

  /// Creates an absent outcome.
  const factory HttpByteRangeOutcome.absent() = _RangeAbsent;

  /// Creates an unsatisfiable outcome.
  const factory HttpByteRangeOutcome.unsatisfiable() = _RangeUnsatisfiable;

  /// Creates a satisfied outcome.
  const factory HttpByteRangeOutcome.satisfied(HttpByteRange range) = _RangeSatisfied;

  /// The satisfied range, when there is one; null for the other
  /// outcomes.
  HttpByteRange? get range => this is _RangeSatisfied ? (this as _RangeSatisfied).range : null;

  /// Whether the request is well-formed but cannot be served (416).
  bool get isUnsatisfiable => this is _RangeUnsatisfiable;

  /// Whether no range applies and the whole resource should be served.
  bool get isAbsent => this is _RangeAbsent;
}

final class _RangeAbsent extends HttpByteRangeOutcome {
  const _RangeAbsent();
}

final class _RangeUnsatisfiable extends HttpByteRangeOutcome {
  const _RangeUnsatisfiable();
}

final class _RangeSatisfied extends HttpByteRangeOutcome {
  const _RangeSatisfied(this.range);

  @override
  final HttpByteRange range;
}

/// The slice arguments for Dart's `File.openRead`, which takes an
/// inclusive start and an **exclusive** end.
extension HttpByteRangeSlice on HttpByteRange {
  /// Inclusive start for `openRead`.
  int get sliceStart => start;

  /// Exclusive end for `openRead`.
  int get sliceEnd => end + 1;
}
