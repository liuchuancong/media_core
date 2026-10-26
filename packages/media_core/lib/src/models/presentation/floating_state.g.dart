// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'floating_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$FloatingState extends FloatingState {
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

  factory _$FloatingState([void Function(FloatingStateBuilder)? updates]) =>
      (FloatingStateBuilder()..update(updates))._build();

  _$FloatingState._({
    required this.active,
    required this.transitioning,
    required this.available,
    required this.enabled,
    required this.generation,
    this.error,
  }) : super._();
  @override
  FloatingState rebuild(void Function(FloatingStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  FloatingStateBuilder toBuilder() => FloatingStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is FloatingState &&
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
    return (newBuiltValueToStringHelper(r'FloatingState')
          ..add('active', active)
          ..add('transitioning', transitioning)
          ..add('available', available)
          ..add('enabled', enabled)
          ..add('generation', generation)
          ..add('error', error))
        .toString();
  }
}

class FloatingStateBuilder
    implements Builder<FloatingState, FloatingStateBuilder> {
  _$FloatingState? _$v;

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

  FloatingStateBuilder() {
    FloatingState._initialize(this);
  }

  FloatingStateBuilder get _$this {
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
  void replace(FloatingState other) {
    _$v = other as _$FloatingState;
  }

  @override
  void update(void Function(FloatingStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  FloatingState build() => _build();

  _$FloatingState _build() {
    final _$result =
        _$v ??
        _$FloatingState._(
          active: BuiltValueNullFieldError.checkNotNull(
            active,
            r'FloatingState',
            'active',
          ),
          transitioning: BuiltValueNullFieldError.checkNotNull(
            transitioning,
            r'FloatingState',
            'transitioning',
          ),
          available: BuiltValueNullFieldError.checkNotNull(
            available,
            r'FloatingState',
            'available',
          ),
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'FloatingState',
            'enabled',
          ),
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'FloatingState',
            'generation',
          ),
          error: error,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
