// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visibility_snapshot.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$VisibilitySnapshot extends VisibilitySnapshot {
  @override
  final VisibilityState state;
  @override
  final DateTime? updatedAt;

  factory _$VisibilitySnapshot([
    void Function(VisibilitySnapshotBuilder)? updates,
  ]) => (VisibilitySnapshotBuilder()..update(updates))._build();

  _$VisibilitySnapshot._({required this.state, this.updatedAt}) : super._();
  @override
  VisibilitySnapshot rebuild(
    void Function(VisibilitySnapshotBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  VisibilitySnapshotBuilder toBuilder() =>
      VisibilitySnapshotBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is VisibilitySnapshot &&
        state == other.state &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'VisibilitySnapshot')
          ..add('state', state)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class VisibilitySnapshotBuilder
    implements Builder<VisibilitySnapshot, VisibilitySnapshotBuilder> {
  _$VisibilitySnapshot? _$v;

  VisibilityStateBuilder? _state;
  VisibilityStateBuilder get state =>
      _$this._state ??= VisibilityStateBuilder();
  set state(VisibilityStateBuilder? state) => _$this._state = state;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  VisibilitySnapshotBuilder();

  VisibilitySnapshotBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _state = $v.state.toBuilder();
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(VisibilitySnapshot other) {
    _$v = other as _$VisibilitySnapshot;
  }

  @override
  void update(void Function(VisibilitySnapshotBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  VisibilitySnapshot build() => _build();

  _$VisibilitySnapshot _build() {
    _$VisibilitySnapshot _$result;
    try {
      _$result =
          _$v ??
          _$VisibilitySnapshot._(state: state.build(), updatedAt: updatedAt);
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'state';
        state.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'VisibilitySnapshot',
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
