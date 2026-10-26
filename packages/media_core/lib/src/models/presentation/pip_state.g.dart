// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pip_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PipState extends PipState {
  @override
  final bool active;
  @override
  final bool transitioning;
  @override
  final bool available;
  @override
  final bool enabled;
  @override
  final int generation;
  @override
  final String? error;

  factory _$PipState([void Function(PipStateBuilder)? updates]) =>
      (PipStateBuilder()..update(updates))._build();

  _$PipState._({
    required this.active,
    required this.transitioning,
    required this.available,
    required this.enabled,
    required this.generation,
    this.error,
  }) : super._();
  @override
  PipState rebuild(void Function(PipStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PipStateBuilder toBuilder() => PipStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PipState &&
        active == other.active &&
        transitioning == other.transitioning &&
        available == other.available &&
        enabled == other.enabled &&
        generation == other.generation &&
        error == other.error;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, active.hashCode);
    _$hash = $jc(_$hash, transitioning.hashCode);
    _$hash = $jc(_$hash, available.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, error.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PipState')
          ..add('active', active)
          ..add('transitioning', transitioning)
          ..add('available', available)
          ..add('enabled', enabled)
          ..add('generation', generation)
          ..add('error', error))
        .toString();
  }
}

class PipStateBuilder implements Builder<PipState, PipStateBuilder> {
  _$PipState? _$v;

  bool? _active;
  bool? get active => _$this._active;
  set active(bool? active) => _$this._active = active;

  bool? _transitioning;
  bool? get transitioning => _$this._transitioning;
  set transitioning(bool? transitioning) =>
      _$this._transitioning = transitioning;

  bool? _available;
  bool? get available => _$this._available;
  set available(bool? available) => _$this._available = available;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  String? _error;
  String? get error => _$this._error;
  set error(String? error) => _$this._error = error;

  PipStateBuilder() {
    PipState._initialize(this);
  }

  PipStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _active = $v.active;
      _transitioning = $v.transitioning;
      _available = $v.available;
      _enabled = $v.enabled;
      _generation = $v.generation;
      _error = $v.error;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PipState other) {
    _$v = other as _$PipState;
  }

  @override
  void update(void Function(PipStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PipState build() => _build();

  _$PipState _build() {
    final _$result =
        _$v ??
        _$PipState._(
          active: BuiltValueNullFieldError.checkNotNull(
            active,
            r'PipState',
            'active',
          ),
          transitioning: BuiltValueNullFieldError.checkNotNull(
            transitioning,
            r'PipState',
            'transitioning',
          ),
          available: BuiltValueNullFieldError.checkNotNull(
            available,
            r'PipState',
            'available',
          ),
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'PipState',
            'enabled',
          ),
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'PipState',
            'generation',
          ),
          error: error,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
