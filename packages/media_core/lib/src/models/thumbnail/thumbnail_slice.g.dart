// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thumbnail_slice.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ThumbnailSlice extends ThumbnailSlice {
  @override
  final int x;
  @override
  final int y;
  @override
  final int width;
  @override
  final int height;

  factory _$ThumbnailSlice([void Function(ThumbnailSliceBuilder)? updates]) =>
      (ThumbnailSliceBuilder()..update(updates))._build();

  _$ThumbnailSlice._({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  }) : super._();
  @override
  ThumbnailSlice rebuild(void Function(ThumbnailSliceBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ThumbnailSliceBuilder toBuilder() => ThumbnailSliceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ThumbnailSlice &&
        x == other.x &&
        y == other.y &&
        width == other.width &&
        height == other.height;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, x.hashCode);
    _$hash = $jc(_$hash, y.hashCode);
    _$hash = $jc(_$hash, width.hashCode);
    _$hash = $jc(_$hash, height.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ThumbnailSlice')
          ..add('x', x)
          ..add('y', y)
          ..add('width', width)
          ..add('height', height))
        .toString();
  }
}

class ThumbnailSliceBuilder
    implements Builder<ThumbnailSlice, ThumbnailSliceBuilder> {
  _$ThumbnailSlice? _$v;

  int? _x;
  int? get x => _$this._x;
  set x(int? x) => _$this._x = x;

  int? _y;
  int? get y => _$this._y;
  set y(int? y) => _$this._y = y;

  int? _width;
  int? get width => _$this._width;
  set width(int? width) => _$this._width = width;

  int? _height;
  int? get height => _$this._height;
  set height(int? height) => _$this._height = height;

  ThumbnailSliceBuilder();

  ThumbnailSliceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _x = $v.x;
      _y = $v.y;
      _width = $v.width;
      _height = $v.height;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ThumbnailSlice other) {
    _$v = other as _$ThumbnailSlice;
  }

  @override
  void update(void Function(ThumbnailSliceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ThumbnailSlice build() => _build();

  _$ThumbnailSlice _build() {
    final _$result =
        _$v ??
        _$ThumbnailSlice._(
          x: BuiltValueNullFieldError.checkNotNull(x, r'ThumbnailSlice', 'x'),
          y: BuiltValueNullFieldError.checkNotNull(y, r'ThumbnailSlice', 'y'),
          width: BuiltValueNullFieldError.checkNotNull(
            width,
            r'ThumbnailSlice',
            'width',
          ),
          height: BuiltValueNullFieldError.checkNotNull(
            height,
            r'ThumbnailSlice',
            'height',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
