// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lifecycle_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LifecycleState extends LifecycleState {
  @override
  final bool created;
  @override
  final bool initialized;
  @override
  final bool active;
  @override
  final bool paused;
  @override
  final bool inactive;
  @override
  final bool detached;
  @override
  final bool disposing;
  @override
  final bool disposed;

  factory _$LifecycleState([void Function(LifecycleStateBuilder)? updates]) =>
      (LifecycleStateBuilder()..update(updates))._build();

  _$LifecycleState._({
    required this.created,
    required this.initialized,
    required this.active,
    required this.paused,
    required this.inactive,
    required this.detached,
    required this.disposing,
    required this.disposed,
  }) : super._();
  @override
  LifecycleState rebuild(void Function(LifecycleStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LifecycleStateBuilder toBuilder() => LifecycleStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LifecycleState &&
        created == other.created &&
        initialized == other.initialized &&
        active == other.active &&
        paused == other.paused &&
        inactive == other.inactive &&
        detached == other.detached &&
        disposing == other.disposing &&
        disposed == other.disposed;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, created.hashCode);
    _$hash = $jc(_$hash, initialized.hashCode);
    _$hash = $jc(_$hash, active.hashCode);
    _$hash = $jc(_$hash, paused.hashCode);
    _$hash = $jc(_$hash, inactive.hashCode);
    _$hash = $jc(_$hash, detached.hashCode);
    _$hash = $jc(_$hash, disposing.hashCode);
    _$hash = $jc(_$hash, disposed.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LifecycleState')
          ..add('created', created)
          ..add('initialized', initialized)
          ..add('active', active)
          ..add('paused', paused)
          ..add('inactive', inactive)
          ..add('detached', detached)
          ..add('disposing', disposing)
          ..add('disposed', disposed))
        .toString();
  }
}

class LifecycleStateBuilder
    implements Builder<LifecycleState, LifecycleStateBuilder> {
  _$LifecycleState? _$v;

  bool? _created;
  bool? get created => _$this._created;
  set created(bool? created) => _$this._created = created;

  bool? _initialized;
  bool? get initialized => _$this._initialized;
  set initialized(bool? initialized) => _$this._initialized = initialized;

  bool? _active;
  bool? get active => _$this._active;
  set active(bool? active) => _$this._active = active;

  bool? _paused;
  bool? get paused => _$this._paused;
  set paused(bool? paused) => _$this._paused = paused;

  bool? _inactive;
  bool? get inactive => _$this._inactive;
  set inactive(bool? inactive) => _$this._inactive = inactive;

  bool? _detached;
  bool? get detached => _$this._detached;
  set detached(bool? detached) => _$this._detached = detached;

  bool? _disposing;
  bool? get disposing => _$this._disposing;
  set disposing(bool? disposing) => _$this._disposing = disposing;

  bool? _disposed;
  bool? get disposed => _$this._disposed;
  set disposed(bool? disposed) => _$this._disposed = disposed;

  LifecycleStateBuilder() {
    LifecycleState._initialize(this);
  }

  LifecycleStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _created = $v.created;
      _initialized = $v.initialized;
      _active = $v.active;
      _paused = $v.paused;
      _inactive = $v.inactive;
      _detached = $v.detached;
      _disposing = $v.disposing;
      _disposed = $v.disposed;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LifecycleState other) {
    _$v = other as _$LifecycleState;
  }

  @override
  void update(void Function(LifecycleStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LifecycleState build() => _build();

  _$LifecycleState _build() {
    final _$result =
        _$v ??
        _$LifecycleState._(
          created: BuiltValueNullFieldError.checkNotNull(
            created,
            r'LifecycleState',
            'created',
          ),
          initialized: BuiltValueNullFieldError.checkNotNull(
            initialized,
            r'LifecycleState',
            'initialized',
          ),
          active: BuiltValueNullFieldError.checkNotNull(
            active,
            r'LifecycleState',
            'active',
          ),
          paused: BuiltValueNullFieldError.checkNotNull(
            paused,
            r'LifecycleState',
            'paused',
          ),
          inactive: BuiltValueNullFieldError.checkNotNull(
            inactive,
            r'LifecycleState',
            'inactive',
          ),
          detached: BuiltValueNullFieldError.checkNotNull(
            detached,
            r'LifecycleState',
            'detached',
          ),
          disposing: BuiltValueNullFieldError.checkNotNull(
            disposing,
            r'LifecycleState',
            'disposing',
          ),
          disposed: BuiltValueNullFieldError.checkNotNull(
            disposed,
            r'LifecycleState',
            'disposed',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
