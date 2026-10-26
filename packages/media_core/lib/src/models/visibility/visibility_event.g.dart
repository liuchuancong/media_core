// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visibility_event.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$VisibilityEvent extends VisibilityEvent {
  @override
  final VisibilityEventType type;
  @override
  final double visibility;
  @override
  final DateTime? timestamp;

  factory _$VisibilityEvent([void Function(VisibilityEventBuilder)? updates]) =>
      (VisibilityEventBuilder()..update(updates))._build();

  _$VisibilityEvent._({
    required this.type,
    required this.visibility,
    this.timestamp,
  }) : super._();
  @override
  VisibilityEvent rebuild(void Function(VisibilityEventBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  VisibilityEventBuilder toBuilder() => VisibilityEventBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is VisibilityEvent &&
        type == other.type &&
        visibility == other.visibility &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, visibility.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'VisibilityEvent')
          ..add('type', type)
          ..add('visibility', visibility)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class VisibilityEventBuilder
    implements Builder<VisibilityEvent, VisibilityEventBuilder> {
  _$VisibilityEvent? _$v;

  VisibilityEventType? _type;
  VisibilityEventType? get type => _$this._type;
  set type(VisibilityEventType? type) => _$this._type = type;

  double? _visibility;
  double? get visibility => _$this._visibility;
  set visibility(double? visibility) => _$this._visibility = visibility;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  VisibilityEventBuilder();

  VisibilityEventBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _visibility = $v.visibility;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(VisibilityEvent other) {
    _$v = other as _$VisibilityEvent;
  }

  @override
  void update(void Function(VisibilityEventBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  VisibilityEvent build() => _build();

  _$VisibilityEvent _build() {
    final _$result =
        _$v ??
        _$VisibilityEvent._(
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'VisibilityEvent',
            'type',
          ),
          visibility: BuiltValueNullFieldError.checkNotNull(
            visibility,
            r'VisibilityEvent',
            'visibility',
          ),
          timestamp: timestamp,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
