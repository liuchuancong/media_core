// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_position.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SchedulePosition extends SchedulePosition {
  @override
  final ScheduledSegment segment;
  @override
  final Duration localTime;
  @override
  final Duration? programTime;

  factory _$SchedulePosition([
    void Function(SchedulePositionBuilder)? updates,
  ]) => (SchedulePositionBuilder()..update(updates))._build();

  _$SchedulePosition._({
    required this.segment,
    required this.localTime,
    this.programTime,
  }) : super._();
  @override
  SchedulePosition rebuild(void Function(SchedulePositionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SchedulePositionBuilder toBuilder() =>
      SchedulePositionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SchedulePosition &&
        segment == other.segment &&
        localTime == other.localTime &&
        programTime == other.programTime;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, segment.hashCode);
    _$hash = $jc(_$hash, localTime.hashCode);
    _$hash = $jc(_$hash, programTime.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SchedulePosition')
          ..add('segment', segment)
          ..add('localTime', localTime)
          ..add('programTime', programTime))
        .toString();
  }
}

class SchedulePositionBuilder
    implements Builder<SchedulePosition, SchedulePositionBuilder> {
  _$SchedulePosition? _$v;

  ScheduledSegmentBuilder? _segment;
  ScheduledSegmentBuilder get segment =>
      _$this._segment ??= ScheduledSegmentBuilder();
  set segment(ScheduledSegmentBuilder? segment) => _$this._segment = segment;

  Duration? _localTime;
  Duration? get localTime => _$this._localTime;
  set localTime(Duration? localTime) => _$this._localTime = localTime;

  Duration? _programTime;
  Duration? get programTime => _$this._programTime;
  set programTime(Duration? programTime) => _$this._programTime = programTime;

  SchedulePositionBuilder();

  SchedulePositionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _segment = $v.segment.toBuilder();
      _localTime = $v.localTime;
      _programTime = $v.programTime;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SchedulePosition other) {
    _$v = other as _$SchedulePosition;
  }

  @override
  void update(void Function(SchedulePositionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SchedulePosition build() => _build();

  _$SchedulePosition _build() {
    _$SchedulePosition _$result;
    try {
      _$result =
          _$v ??
          _$SchedulePosition._(
            segment: segment.build(),
            localTime: BuiltValueNullFieldError.checkNotNull(
              localTime,
              r'SchedulePosition',
              'localTime',
            ),
            programTime: programTime,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'segment';
        segment.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SchedulePosition',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
