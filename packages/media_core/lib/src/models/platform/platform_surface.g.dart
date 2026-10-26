// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_surface.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlatformSurface extends PlatformSurface {
  @override
  final PlatformSurfaceType type;
  @override
  final int? id;
  @override
  final bool supportsResize;
  @override
  final bool supportsRotation;
  @override
  final bool requiresRecreationOnSizeChange;
  @override
  final bool persistent;

  factory _$PlatformSurface([void Function(PlatformSurfaceBuilder)? updates]) =>
      (PlatformSurfaceBuilder()..update(updates))._build();

  _$PlatformSurface._({
    required this.type,
    this.id,
    required this.supportsResize,
    required this.supportsRotation,
    required this.requiresRecreationOnSizeChange,
    required this.persistent,
  }) : super._();
  @override
  PlatformSurface rebuild(void Function(PlatformSurfaceBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlatformSurfaceBuilder toBuilder() => PlatformSurfaceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlatformSurface &&
        type == other.type &&
        id == other.id &&
        supportsResize == other.supportsResize &&
        supportsRotation == other.supportsRotation &&
        requiresRecreationOnSizeChange ==
            other.requiresRecreationOnSizeChange &&
        persistent == other.persistent;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, supportsResize.hashCode);
    _$hash = $jc(_$hash, supportsRotation.hashCode);
    _$hash = $jc(_$hash, requiresRecreationOnSizeChange.hashCode);
    _$hash = $jc(_$hash, persistent.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlatformSurface')
          ..add('type', type)
          ..add('id', id)
          ..add('supportsResize', supportsResize)
          ..add('supportsRotation', supportsRotation)
          ..add(
            'requiresRecreationOnSizeChange',
            requiresRecreationOnSizeChange,
          )
          ..add('persistent', persistent))
        .toString();
  }
}

class PlatformSurfaceBuilder
    implements Builder<PlatformSurface, PlatformSurfaceBuilder> {
  _$PlatformSurface? _$v;

  PlatformSurfaceType? _type;
  PlatformSurfaceType? get type => _$this._type;
  set type(PlatformSurfaceType? type) => _$this._type = type;

  int? _id;
  int? get id => _$this._id;
  set id(int? id) => _$this._id = id;

  bool? _supportsResize;
  bool? get supportsResize => _$this._supportsResize;
  set supportsResize(bool? supportsResize) =>
      _$this._supportsResize = supportsResize;

  bool? _supportsRotation;
  bool? get supportsRotation => _$this._supportsRotation;
  set supportsRotation(bool? supportsRotation) =>
      _$this._supportsRotation = supportsRotation;

  bool? _requiresRecreationOnSizeChange;
  bool? get requiresRecreationOnSizeChange =>
      _$this._requiresRecreationOnSizeChange;
  set requiresRecreationOnSizeChange(bool? requiresRecreationOnSizeChange) =>
      _$this._requiresRecreationOnSizeChange = requiresRecreationOnSizeChange;

  bool? _persistent;
  bool? get persistent => _$this._persistent;
  set persistent(bool? persistent) => _$this._persistent = persistent;

  PlatformSurfaceBuilder() {
    PlatformSurface._initialize(this);
  }

  PlatformSurfaceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _id = $v.id;
      _supportsResize = $v.supportsResize;
      _supportsRotation = $v.supportsRotation;
      _requiresRecreationOnSizeChange = $v.requiresRecreationOnSizeChange;
      _persistent = $v.persistent;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlatformSurface other) {
    _$v = other as _$PlatformSurface;
  }

  @override
  void update(void Function(PlatformSurfaceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlatformSurface build() => _build();

  _$PlatformSurface _build() {
    final _$result =
        _$v ??
        _$PlatformSurface._(
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'PlatformSurface',
            'type',
          ),
          id: id,
          supportsResize: BuiltValueNullFieldError.checkNotNull(
            supportsResize,
            r'PlatformSurface',
            'supportsResize',
          ),
          supportsRotation: BuiltValueNullFieldError.checkNotNull(
            supportsRotation,
            r'PlatformSurface',
            'supportsRotation',
          ),
          requiresRecreationOnSizeChange: BuiltValueNullFieldError.checkNotNull(
            requiresRecreationOnSizeChange,
            r'PlatformSurface',
            'requiresRecreationOnSizeChange',
          ),
          persistent: BuiltValueNullFieldError.checkNotNull(
            persistent,
            r'PlatformSurface',
            'persistent',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
