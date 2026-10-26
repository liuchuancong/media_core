// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_timeout.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OperationTimeout extends OperationTimeout {
  @override
  final Duration duration;
  @override
  final bool enabled;

  factory _$OperationTimeout([
    void Function(OperationTimeoutBuilder)? updates,
  ]) => (OperationTimeoutBuilder()..update(updates))._build();

  _$OperationTimeout._({required this.duration, required this.enabled})
    : super._();
  @override
  OperationTimeout rebuild(void Function(OperationTimeoutBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  OperationTimeoutBuilder toBuilder() =>
      OperationTimeoutBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OperationTimeout &&
        duration == other.duration &&
        enabled == other.enabled;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, duration.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OperationTimeout')
          ..add('duration', duration)
          ..add('enabled', enabled))
        .toString();
  }
}

class OperationTimeoutBuilder
    implements Builder<OperationTimeout, OperationTimeoutBuilder> {
  _$OperationTimeout? _$v;

  Duration? _duration;
  Duration? get duration => _$this._duration;
  set duration(Duration? duration) => _$this._duration = duration;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  OperationTimeoutBuilder() {
    OperationTimeout._initialize(this);
  }

  OperationTimeoutBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _duration = $v.duration;
      _enabled = $v.enabled;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OperationTimeout other) {
    _$v = other as _$OperationTimeout;
  }

  @override
  void update(void Function(OperationTimeoutBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OperationTimeout build() => _build();

  _$OperationTimeout _build() {
    OperationTimeout._validate(this);
    final _$result =
        _$v ??
        _$OperationTimeout._(
          duration: BuiltValueNullFieldError.checkNotNull(
            duration,
            r'OperationTimeout',
            'duration',
          ),
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'OperationTimeout',
            'enabled',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
