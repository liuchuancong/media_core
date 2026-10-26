// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_location.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SourceLocation extends SourceLocation {
  @override
  final Uri? uri;
  @override
  final String? path;
  @override
  final String? asset;
  @override
  final String? custom;
  @override
  final SourceLocationType type;

  factory _$SourceLocation([void Function(SourceLocationBuilder)? updates]) =>
      (SourceLocationBuilder()..update(updates))._build();

  _$SourceLocation._({
    this.uri,
    this.path,
    this.asset,
    this.custom,
    required this.type,
  }) : super._();
  @override
  SourceLocation rebuild(void Function(SourceLocationBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SourceLocationBuilder toBuilder() => SourceLocationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SourceLocation &&
        uri == other.uri &&
        path == other.path &&
        asset == other.asset &&
        custom == other.custom &&
        type == other.type;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, uri.hashCode);
    _$hash = $jc(_$hash, path.hashCode);
    _$hash = $jc(_$hash, asset.hashCode);
    _$hash = $jc(_$hash, custom.hashCode);
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SourceLocation')
          ..add('uri', uri)
          ..add('path', path)
          ..add('asset', asset)
          ..add('custom', custom)
          ..add('type', type))
        .toString();
  }
}

class SourceLocationBuilder
    implements Builder<SourceLocation, SourceLocationBuilder> {
  _$SourceLocation? _$v;

  Uri? _uri;
  Uri? get uri => _$this._uri;
  set uri(Uri? uri) => _$this._uri = uri;

  String? _path;
  String? get path => _$this._path;
  set path(String? path) => _$this._path = path;

  String? _asset;
  String? get asset => _$this._asset;
  set asset(String? asset) => _$this._asset = asset;

  String? _custom;
  String? get custom => _$this._custom;
  set custom(String? custom) => _$this._custom = custom;

  SourceLocationType? _type;
  SourceLocationType? get type => _$this._type;
  set type(SourceLocationType? type) => _$this._type = type;

  SourceLocationBuilder() {
    SourceLocation._initialize(this);
  }

  SourceLocationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _uri = $v.uri;
      _path = $v.path;
      _asset = $v.asset;
      _custom = $v.custom;
      _type = $v.type;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SourceLocation other) {
    _$v = other as _$SourceLocation;
  }

  @override
  void update(void Function(SourceLocationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SourceLocation build() => _build();

  _$SourceLocation _build() {
    final _$result =
        _$v ??
        _$SourceLocation._(
          uri: uri,
          path: path,
          asset: asset,
          custom: custom,
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'SourceLocation',
            'type',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
