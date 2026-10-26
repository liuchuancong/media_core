// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preload_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PreloadState extends PreloadState {
  @override
  final bool pending;
  @override
  final bool loading;
  @override
  final bool completed;
  @override
  final bool failed;
  @override
  final bool cancelled;

  factory _$PreloadState([void Function(PreloadStateBuilder)? updates]) =>
      (PreloadStateBuilder()..update(updates))._build();

  _$PreloadState._({
    required this.pending,
    required this.loading,
    required this.completed,
    required this.failed,
    required this.cancelled,
  }) : super._();
  @override
  PreloadState rebuild(void Function(PreloadStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PreloadStateBuilder toBuilder() => PreloadStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PreloadState &&
        pending == other.pending &&
        loading == other.loading &&
        completed == other.completed &&
        failed == other.failed &&
        cancelled == other.cancelled;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, pending.hashCode);
    _$hash = $jc(_$hash, loading.hashCode);
    _$hash = $jc(_$hash, completed.hashCode);
    _$hash = $jc(_$hash, failed.hashCode);
    _$hash = $jc(_$hash, cancelled.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PreloadState')
          ..add('pending', pending)
          ..add('loading', loading)
          ..add('completed', completed)
          ..add('failed', failed)
          ..add('cancelled', cancelled))
        .toString();
  }
}

class PreloadStateBuilder
    implements Builder<PreloadState, PreloadStateBuilder> {
  _$PreloadState? _$v;

  bool? _pending;
  bool? get pending => _$this._pending;
  set pending(bool? pending) => _$this._pending = pending;

  bool? _loading;
  bool? get loading => _$this._loading;
  set loading(bool? loading) => _$this._loading = loading;

  bool? _completed;
  bool? get completed => _$this._completed;
  set completed(bool? completed) => _$this._completed = completed;

  bool? _failed;
  bool? get failed => _$this._failed;
  set failed(bool? failed) => _$this._failed = failed;

  bool? _cancelled;
  bool? get cancelled => _$this._cancelled;
  set cancelled(bool? cancelled) => _$this._cancelled = cancelled;

  PreloadStateBuilder() {
    PreloadState._initialize(this);
  }

  PreloadStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _pending = $v.pending;
      _loading = $v.loading;
      _completed = $v.completed;
      _failed = $v.failed;
      _cancelled = $v.cancelled;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PreloadState other) {
    _$v = other as _$PreloadState;
  }

  @override
  void update(void Function(PreloadStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PreloadState build() => _build();

  _$PreloadState _build() {
    final _$result =
        _$v ??
        _$PreloadState._(
          pending: BuiltValueNullFieldError.checkNotNull(
            pending,
            r'PreloadState',
            'pending',
          ),
          loading: BuiltValueNullFieldError.checkNotNull(
            loading,
            r'PreloadState',
            'loading',
          ),
          completed: BuiltValueNullFieldError.checkNotNull(
            completed,
            r'PreloadState',
            'completed',
          ),
          failed: BuiltValueNullFieldError.checkNotNull(
            failed,
            r'PreloadState',
            'failed',
          ),
          cancelled: BuiltValueNullFieldError.checkNotNull(
            cancelled,
            r'PreloadState',
            'cancelled',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
