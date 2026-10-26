// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lifecycle_event.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LifecycleEvent extends LifecycleEvent {
  @override
  final LifecycleEventType type;
  @override
  final DateTime? timestamp;

  factory _$LifecycleEvent([void Function(LifecycleEventBuilder)? updates]) =>
      (LifecycleEventBuilder()..update(updates))._build();

  _$LifecycleEvent._({required this.type, this.timestamp}) : super._();
  @override
  LifecycleEvent rebuild(void Function(LifecycleEventBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LifecycleEventBuilder toBuilder() => LifecycleEventBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LifecycleEvent &&
        type == other.type &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LifecycleEvent')
          ..add('type', type)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class LifecycleEventBuilder
    implements Builder<LifecycleEvent, LifecycleEventBuilder> {
  _$LifecycleEvent? _$v;

  LifecycleEventType? _type;
  LifecycleEventType? get type => _$this._type;
  set type(LifecycleEventType? type) => _$this._type = type;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  LifecycleEventBuilder();

  LifecycleEventBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LifecycleEvent other) {
    _$v = other as _$LifecycleEvent;
  }

  @override
  void update(void Function(LifecycleEventBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LifecycleEvent build() => _build();

  _$LifecycleEvent _build() {
    final _$result =
        _$v ??
        _$LifecycleEvent._(
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'LifecycleEvent',
            'type',
          ),
          timestamp: timestamp,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
