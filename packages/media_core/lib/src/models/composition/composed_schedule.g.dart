// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'composed_schedule.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ComposedSchedule extends ComposedSchedule {
  @override
  final List<ScheduledSegment> segments;

  factory _$ComposedSchedule([
    void Function(ComposedScheduleBuilder)? updates,
  ]) => (ComposedScheduleBuilder()..update(updates))._build();

  _$ComposedSchedule._({required this.segments}) : super._();
  @override
  ComposedSchedule rebuild(void Function(ComposedScheduleBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ComposedScheduleBuilder toBuilder() =>
      ComposedScheduleBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ComposedSchedule && segments == other.segments;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, segments.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'ComposedSchedule',
    )..add('segments', segments)).toString();
  }
}

class ComposedScheduleBuilder
    implements Builder<ComposedSchedule, ComposedScheduleBuilder> {
  _$ComposedSchedule? _$v;

  List<ScheduledSegment>? _segments;
  List<ScheduledSegment>? get segments => _$this._segments;
  set segments(List<ScheduledSegment>? segments) => _$this._segments = segments;

  ComposedScheduleBuilder();

  ComposedScheduleBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _segments = $v.segments;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ComposedSchedule other) {
    _$v = other as _$ComposedSchedule;
  }

  @override
  void update(void Function(ComposedScheduleBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ComposedSchedule build() => _build();

  _$ComposedSchedule _build() {
    ComposedSchedule._validate(this);
    final _$result =
        _$v ??
        _$ComposedSchedule._(
          segments: BuiltValueNullFieldError.checkNotNull(
            segments,
            r'ComposedSchedule',
            'segments',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
