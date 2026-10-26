import 'package:built_value/built_value.dart';

part 'thumbnail_slice.g.dart';

/// A rectangle inside a thumbnail sprite image.
///
/// WebVTT thumbnail tracks pack many preview frames into one sprite and
/// address each one with a `#xywh=x,y,w,h` fragment on the cue's image
/// URL; [ThumbnailSlice] is that fragment after parsing, and nothing
/// more. The UI crops with it — media_core has no image decoder here,
/// and a slice is the whole contract between a data track and a
/// renderer.
abstract class ThumbnailSlice implements Built<ThumbnailSlice, ThumbnailSliceBuilder> {
  /// Builds a slice from a [updates] callback — the codegen entry.
  factory ThumbnailSlice([void Function(ThumbnailSliceBuilder)? updates]) = _$ThumbnailSlice;

  /// Creates a slice at ([x], [y]) of size [width] by [height].
  factory ThumbnailSlice.of({required int x, required int y, required int width, required int height}) {
    return ThumbnailSlice(
      (builder) => builder
        ..x = x
        ..y = y
        ..width = width
        ..height = height,
    );
  }

  ThumbnailSlice._();

  /// Parses the value of an `xywh` URI fragment, e.g. `160,0,160,90`.
  ///
  /// Returns null for anything that is not four comma-separated
  /// integers. A trailing `t` (temporal fragment) or a percent form is
  /// not accepted: the WebVTT thumbnail profile in real use is pixel
  /// xywh, and silently accepting a syntax no one produces would
  /// promise a decoding path that does not exist.
  static ThumbnailSlice? tryParse(String raw) {
    final parts = raw.split(',');
    if (parts.length != 4) {
      return null;
    }
    final values = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part.trim());
      if (value == null) {
        return null;
      }
      values.add(value);
    }
    return ThumbnailSlice.of(x: values[0], y: values[1], width: values[2], height: values[3]);
  }

  /// Horizontal offset inside the sprite, in pixels.
  int get x;

  /// Vertical offset inside the sprite, in pixels.
  int get y;

  /// Width of the frame inside the sprite, in pixels.
  int get width;

  /// Height of the frame inside the sprite, in pixels.
  int get height;
}
