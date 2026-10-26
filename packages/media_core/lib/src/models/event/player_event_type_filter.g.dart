// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_event_type_filter.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerEventTypeFilter extends PlayerEventTypeFilter {
  @override
  final Set<PlayerEventType> types;
  @override
  final bool acceptAll;

  factory _$PlayerEventTypeFilter([
    void Function(PlayerEventTypeFilterBuilder)? updates,
  ]) => (PlayerEventTypeFilterBuilder()..update(updates))._build();

  _$PlayerEventTypeFilter._({required this.types, required this.acceptAll})
    : super._();
  @override
  PlayerEventTypeFilter rebuild(
    void Function(PlayerEventTypeFilterBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PlayerEventTypeFilterBuilder toBuilder() =>
      PlayerEventTypeFilterBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerEventTypeFilter &&
        types == other.types &&
        acceptAll == other.acceptAll;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, types.hashCode);
    _$hash = $jc(_$hash, acceptAll.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerEventTypeFilter')
          ..add('types', types)
          ..add('acceptAll', acceptAll))
        .toString();
  }
}

class PlayerEventTypeFilterBuilder
    implements Builder<PlayerEventTypeFilter, PlayerEventTypeFilterBuilder> {
  _$PlayerEventTypeFilter? _$v;

  Set<PlayerEventType>? _types;
  Set<PlayerEventType>? get types => _$this._types;
  set types(Set<PlayerEventType>? types) => _$this._types = types;

  bool? _acceptAll;
  bool? get acceptAll => _$this._acceptAll;
  set acceptAll(bool? acceptAll) => _$this._acceptAll = acceptAll;

  PlayerEventTypeFilterBuilder() {
    PlayerEventTypeFilter._initialize(this);
  }

  PlayerEventTypeFilterBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _types = $v.types;
      _acceptAll = $v.acceptAll;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerEventTypeFilter other) {
    _$v = other as _$PlayerEventTypeFilter;
  }

  @override
  void update(void Function(PlayerEventTypeFilterBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerEventTypeFilter build() => _build();

  _$PlayerEventTypeFilter _build() {
    final _$result =
        _$v ??
        _$PlayerEventTypeFilter._(
          types: BuiltValueNullFieldError.checkNotNull(
            types,
            r'PlayerEventTypeFilter',
            'types',
          ),
          acceptAll: BuiltValueNullFieldError.checkNotNull(
            acceptAll,
            r'PlayerEventTypeFilter',
            'acceptAll',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
