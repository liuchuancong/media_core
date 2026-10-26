// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_route.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AudioRoute extends AudioRoute {
  @override
  final String id;
  @override
  final String name;
  @override
  final AudioRouteKind kind;
  @override
  final bool isDefault;
  @override
  final bool isAvailable;

  factory _$AudioRoute([void Function(AudioRouteBuilder)? updates]) =>
      (AudioRouteBuilder()..update(updates))._build();

  _$AudioRoute._({
    required this.id,
    required this.name,
    required this.kind,
    required this.isDefault,
    required this.isAvailable,
  }) : super._();
  @override
  AudioRoute rebuild(void Function(AudioRouteBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AudioRouteBuilder toBuilder() => AudioRouteBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AudioRoute &&
        id == other.id &&
        name == other.name &&
        kind == other.kind &&
        isDefault == other.isDefault &&
        isAvailable == other.isAvailable;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, isDefault.hashCode);
    _$hash = $jc(_$hash, isAvailable.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AudioRoute')
          ..add('id', id)
          ..add('name', name)
          ..add('kind', kind)
          ..add('isDefault', isDefault)
          ..add('isAvailable', isAvailable))
        .toString();
  }
}

class AudioRouteBuilder implements Builder<AudioRoute, AudioRouteBuilder> {
  _$AudioRoute? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  AudioRouteKind? _kind;
  AudioRouteKind? get kind => _$this._kind;
  set kind(AudioRouteKind? kind) => _$this._kind = kind;

  bool? _isDefault;
  bool? get isDefault => _$this._isDefault;
  set isDefault(bool? isDefault) => _$this._isDefault = isDefault;

  bool? _isAvailable;
  bool? get isAvailable => _$this._isAvailable;
  set isAvailable(bool? isAvailable) => _$this._isAvailable = isAvailable;

  AudioRouteBuilder() {
    AudioRoute._initialize(this);
  }

  AudioRouteBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _kind = $v.kind;
      _isDefault = $v.isDefault;
      _isAvailable = $v.isAvailable;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AudioRoute other) {
    _$v = other as _$AudioRoute;
  }

  @override
  void update(void Function(AudioRouteBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AudioRoute build() => _build();

  _$AudioRoute _build() {
    final _$result =
        _$v ??
        _$AudioRoute._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'AudioRoute', 'id'),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'AudioRoute',
            'name',
          ),
          kind: BuiltValueNullFieldError.checkNotNull(
            kind,
            r'AudioRoute',
            'kind',
          ),
          isDefault: BuiltValueNullFieldError.checkNotNull(
            isDefault,
            r'AudioRoute',
            'isDefault',
          ),
          isAvailable: BuiltValueNullFieldError.checkNotNull(
            isAvailable,
            r'AudioRoute',
            'isAvailable',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
