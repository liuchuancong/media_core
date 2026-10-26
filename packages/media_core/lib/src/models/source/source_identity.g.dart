// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_identity.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SourceIdentity extends SourceIdentity {
  @override
  final SourceId id;
  @override
  final String? provider;
  @override
  final String? externalId;
  @override
  final String? name;
  @override
  final String? namespace;
  @override
  final Map<String, Object?> attributes;

  factory _$SourceIdentity([void Function(SourceIdentityBuilder)? updates]) =>
      (SourceIdentityBuilder()..update(updates))._build();

  _$SourceIdentity._({
    required this.id,
    this.provider,
    this.externalId,
    this.name,
    this.namespace,
    required this.attributes,
  }) : super._();
  @override
  SourceIdentity rebuild(void Function(SourceIdentityBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SourceIdentityBuilder toBuilder() => SourceIdentityBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SourceIdentity &&
        id == other.id &&
        provider == other.provider &&
        externalId == other.externalId &&
        name == other.name &&
        namespace == other.namespace &&
        attributes == other.attributes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, provider.hashCode);
    _$hash = $jc(_$hash, externalId.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, namespace.hashCode);
    _$hash = $jc(_$hash, attributes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SourceIdentity')
          ..add('id', id)
          ..add('provider', provider)
          ..add('externalId', externalId)
          ..add('name', name)
          ..add('namespace', namespace)
          ..add('attributes', attributes))
        .toString();
  }
}

class SourceIdentityBuilder
    implements Builder<SourceIdentity, SourceIdentityBuilder> {
  _$SourceIdentity? _$v;

  SourceId? _id;
  SourceId? get id => _$this._id;
  set id(SourceId? id) => _$this._id = id;

  String? _provider;
  String? get provider => _$this._provider;
  set provider(String? provider) => _$this._provider = provider;

  String? _externalId;
  String? get externalId => _$this._externalId;
  set externalId(String? externalId) => _$this._externalId = externalId;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _namespace;
  String? get namespace => _$this._namespace;
  set namespace(String? namespace) => _$this._namespace = namespace;

  Map<String, Object?>? _attributes;
  Map<String, Object?>? get attributes => _$this._attributes;
  set attributes(Map<String, Object?>? attributes) =>
      _$this._attributes = attributes;

  SourceIdentityBuilder() {
    SourceIdentity._initialize(this);
  }

  SourceIdentityBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _provider = $v.provider;
      _externalId = $v.externalId;
      _name = $v.name;
      _namespace = $v.namespace;
      _attributes = $v.attributes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SourceIdentity other) {
    _$v = other as _$SourceIdentity;
  }

  @override
  void update(void Function(SourceIdentityBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SourceIdentity build() => _build();

  _$SourceIdentity _build() {
    final _$result =
        _$v ??
        _$SourceIdentity._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'SourceIdentity',
            'id',
          ),
          provider: provider,
          externalId: externalId,
          name: name,
          namespace: namespace,
          attributes: BuiltValueNullFieldError.checkNotNull(
            attributes,
            r'SourceIdentity',
            'attributes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
