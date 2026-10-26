// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reconcile_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ReconcileState extends ReconcileState {
  @override
  final bool running;
  @override
  final bool completed;
  @override
  final bool failed;
  @override
  final int pendingActions;

  factory _$ReconcileState([void Function(ReconcileStateBuilder)? updates]) =>
      (ReconcileStateBuilder()..update(updates))._build();

  _$ReconcileState._({
    required this.running,
    required this.completed,
    required this.failed,
    required this.pendingActions,
  }) : super._();
  @override
  ReconcileState rebuild(void Function(ReconcileStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ReconcileStateBuilder toBuilder() => ReconcileStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ReconcileState &&
        running == other.running &&
        completed == other.completed &&
        failed == other.failed &&
        pendingActions == other.pendingActions;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, running.hashCode);
    _$hash = $jc(_$hash, completed.hashCode);
    _$hash = $jc(_$hash, failed.hashCode);
    _$hash = $jc(_$hash, pendingActions.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ReconcileState')
          ..add('running', running)
          ..add('completed', completed)
          ..add('failed', failed)
          ..add('pendingActions', pendingActions))
        .toString();
  }
}

class ReconcileStateBuilder
    implements Builder<ReconcileState, ReconcileStateBuilder> {
  _$ReconcileState? _$v;

  bool? _running;
  bool? get running => _$this._running;
  set running(bool? running) => _$this._running = running;

  bool? _completed;
  bool? get completed => _$this._completed;
  set completed(bool? completed) => _$this._completed = completed;

  bool? _failed;
  bool? get failed => _$this._failed;
  set failed(bool? failed) => _$this._failed = failed;

  int? _pendingActions;
  int? get pendingActions => _$this._pendingActions;
  set pendingActions(int? pendingActions) =>
      _$this._pendingActions = pendingActions;

  ReconcileStateBuilder() {
    ReconcileState._initialize(this);
  }

  ReconcileStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _running = $v.running;
      _completed = $v.completed;
      _failed = $v.failed;
      _pendingActions = $v.pendingActions;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ReconcileState other) {
    _$v = other as _$ReconcileState;
  }

  @override
  void update(void Function(ReconcileStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ReconcileState build() => _build();

  _$ReconcileState _build() {
    final _$result =
        _$v ??
        _$ReconcileState._(
          running: BuiltValueNullFieldError.checkNotNull(
            running,
            r'ReconcileState',
            'running',
          ),
          completed: BuiltValueNullFieldError.checkNotNull(
            completed,
            r'ReconcileState',
            'completed',
          ),
          failed: BuiltValueNullFieldError.checkNotNull(
            failed,
            r'ReconcileState',
            'failed',
          ),
          pendingActions: BuiltValueNullFieldError.checkNotNull(
            pendingActions,
            r'ReconcileState',
            'pendingActions',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
