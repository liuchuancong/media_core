// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thumbnail.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Thumbnail extends Thumbnail {
  @override
  final Duration start;
  @override
  final Duration end;
  @override
  final Uri imageUrl;
  @override
  final ThumbnailSlice? slice;

  factory _$Thumbnail([void Function(ThumbnailBuilder)? updates]) =>
      (ThumbnailBuilder()..update(updates))._build();

  _$Thumbnail._({
    required this.start,
    required this.end,
    required this.imageUrl,
    this.slice,
  }) : super._();
  @override
  Thumbnail rebuild(void Function(ThumbnailBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ThumbnailBuilder toBuilder() => ThumbnailBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Thumbnail &&
        start == other.start &&
        end == other.end &&
        imageUrl == other.imageUrl &&
        slice == other.slice;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, start.hashCode);
    _$hash = $jc(_$hash, end.hashCode);
    _$hash = $jc(_$hash, imageUrl.hashCode);
    _$hash = $jc(_$hash, slice.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Thumbnail')
          ..add('start', start)
          ..add('end', end)
          ..add('imageUrl', imageUrl)
          ..add('slice', slice))
        .toString();
  }
}

class ThumbnailBuilder implements Builder<Thumbnail, ThumbnailBuilder> {
  _$Thumbnail? _$v;

  Duration? _start;
  Duration? get start => _$this._start;
  set start(Duration? start) => _$this._start = start;

  Duration? _end;
  Duration? get end => _$this._end;
  set end(Duration? end) => _$this._end = end;

  Uri? _imageUrl;
  Uri? get imageUrl => _$this._imageUrl;
  set imageUrl(Uri? imageUrl) => _$this._imageUrl = imageUrl;

  ThumbnailSliceBuilder? _slice;
  ThumbnailSliceBuilder get slice => _$this._slice ??= ThumbnailSliceBuilder();
  set slice(ThumbnailSliceBuilder? slice) => _$this._slice = slice;

  ThumbnailBuilder();

  ThumbnailBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _start = $v.start;
      _end = $v.end;
      _imageUrl = $v.imageUrl;
      _slice = $v.slice?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Thumbnail other) {
    _$v = other as _$Thumbnail;
  }

  @override
  void update(void Function(ThumbnailBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Thumbnail build() => _build();

  _$Thumbnail _build() {
    _$Thumbnail _$result;
    try {
      _$result =
          _$v ??
          _$Thumbnail._(
            start: BuiltValueNullFieldError.checkNotNull(
              start,
              r'Thumbnail',
              'start',
            ),
            end: BuiltValueNullFieldError.checkNotNull(
              end,
              r'Thumbnail',
              'end',
            ),
            imageUrl: BuiltValueNullFieldError.checkNotNull(
              imageUrl,
              r'Thumbnail',
              'imageUrl',
            ),
            slice: _slice?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'slice';
        _slice?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'Thumbnail',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
