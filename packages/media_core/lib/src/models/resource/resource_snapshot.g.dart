// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resource_snapshot.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResourceSnapshot extends ResourceSnapshot {
  @override
  final ResourceState state;
  @override
  final DateTime createdAt;

  factory _$ResourceSnapshot([
    void Function(ResourceSnapshotBuilder)? updates,
  ]) => (ResourceSnapshotBuilder()..update(updates))._build();

  _$ResourceSnapshot._({required this.state, required this.createdAt})
    : super._();
  @override
  ResourceSnapshot rebuild(void Function(ResourceSnapshotBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ResourceSnapshotBuilder toBuilder() =>
      ResourceSnapshotBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResourceSnapshot &&
        state == other.state &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ResourceSnapshot')
          ..add('state', state)
          ..add('createdAt', createdAt))
        .toString();
  }
}

class ResourceSnapshotBuilder
    implements Builder<ResourceSnapshot, ResourceSnapshotBuilder> {
  _$ResourceSnapshot? _$v;

  ResourceState? _state;
  ResourceState? get state => _$this._state;
  set state(ResourceState? state) => _$this._state = state;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  ResourceSnapshotBuilder();

  ResourceSnapshotBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _state = $v.state;
      _createdAt = $v.createdAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResourceSnapshot other) {
    _$v = other as _$ResourceSnapshot;
  }

  @override
  void update(void Function(ResourceSnapshotBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResourceSnapshot build() => _build();

  _$ResourceSnapshot _build() {
    final _$result =
        _$v ??
        _$ResourceSnapshot._(
          state: BuiltValueNullFieldError.checkNotNull(
            state,
            r'ResourceSnapshot',
            'state',
          ),
          createdAt: BuiltValueNullFieldError.checkNotNull(
            createdAt,
            r'ResourceSnapshot',
            'createdAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
