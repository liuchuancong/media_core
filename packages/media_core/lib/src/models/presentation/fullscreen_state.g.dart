// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fullscreen_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$FullscreenState extends FullscreenState {
  @override
  final bool active;
  @override
  final bool transitioning;
  @override
  final bool available;
  @override
  final int generation;
  @override
  final String? error;

  factory _$FullscreenState([void Function(FullscreenStateBuilder)? updates]) =>
      (FullscreenStateBuilder()..update(updates))._build();

  _$FullscreenState._({
    required this.active,
    required this.transitioning,
    required this.available,
    required this.generation,
    this.error,
  }) : super._();
  @override
  FullscreenState rebuild(void Function(FullscreenStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  FullscreenStateBuilder toBuilder() => FullscreenStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is FullscreenState &&
        active == other.active &&
        transitioning == other.transitioning &&
        available == other.available &&
        generation == other.generation &&
        error == other.error;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, active.hashCode);
    _$hash = $jc(_$hash, transitioning.hashCode);
    _$hash = $jc(_$hash, available.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, error.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'FullscreenState')
          ..add('active', active)
          ..add('transitioning', transitioning)
          ..add('available', available)
          ..add('generation', generation)
          ..add('error', error))
        .toString();
  }
}

class FullscreenStateBuilder
    implements Builder<FullscreenState, FullscreenStateBuilder> {
  _$FullscreenState? _$v;

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

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  String? _error;
  String? get error => _$this._error;
  set error(String? error) => _$this._error = error;

  FullscreenStateBuilder() {
    FullscreenState._initialize(this);
  }

  FullscreenStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _active = $v.active;
      _transitioning = $v.transitioning;
      _available = $v.available;
      _generation = $v.generation;
      _error = $v.error;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(FullscreenState other) {
    _$v = other as _$FullscreenState;
  }

  @override
  void update(void Function(FullscreenStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  FullscreenState build() => _build();

  _$FullscreenState _build() {
    final _$result =
        _$v ??
        _$FullscreenState._(
          active: BuiltValueNullFieldError.checkNotNull(
            active,
            r'FullscreenState',
            'active',
          ),
          transitioning: BuiltValueNullFieldError.checkNotNull(
            transitioning,
            r'FullscreenState',
            'transitioning',
          ),
          available: BuiltValueNullFieldError.checkNotNull(
            available,
            r'FullscreenState',
            'available',
          ),
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'FullscreenState',
            'generation',
          ),
          error: error,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
