// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_segment.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ScheduledSegment extends ScheduledSegment {
  @override
  final ScheduleClip clip;
  @override
  final Duration start;
  @override
  final Duration end;
  @override
  final Duration? programTime;

  factory _$ScheduledSegment([
    void Function(ScheduledSegmentBuilder)? updates,
  ]) => (ScheduledSegmentBuilder()..update(updates))._build();

  _$ScheduledSegment._({
    required this.clip,
    required this.start,
    required this.end,
    this.programTime,
  }) : super._();
  @override
  ScheduledSegment rebuild(void Function(ScheduledSegmentBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ScheduledSegmentBuilder toBuilder() =>
      ScheduledSegmentBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ScheduledSegment &&
        clip == other.clip &&
        start == other.start &&
        end == other.end &&
        programTime == other.programTime;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, clip.hashCode);
    _$hash = $jc(_$hash, start.hashCode);
    _$hash = $jc(_$hash, end.hashCode);
    _$hash = $jc(_$hash, programTime.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ScheduledSegment')
          ..add('clip', clip)
          ..add('start', start)
          ..add('end', end)
          ..add('programTime', programTime))
        .toString();
  }
}

class ScheduledSegmentBuilder
    implements Builder<ScheduledSegment, ScheduledSegmentBuilder> {
  _$ScheduledSegment? _$v;

  ScheduleClipBuilder? _clip;
  ScheduleClipBuilder get clip => _$this._clip ??= ScheduleClipBuilder();
  set clip(ScheduleClipBuilder? clip) => _$this._clip = clip;

  Duration? _start;
  Duration? get start => _$this._start;
  set start(Duration? start) => _$this._start = start;

  Duration? _end;
  Duration? get end => _$this._end;
  set end(Duration? end) => _$this._end = end;

  Duration? _programTime;
  Duration? get programTime => _$this._programTime;
  set programTime(Duration? programTime) => _$this._programTime = programTime;

  ScheduledSegmentBuilder();

  ScheduledSegmentBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _clip = $v.clip.toBuilder();
      _start = $v.start;
      _end = $v.end;
      _programTime = $v.programTime;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ScheduledSegment other) {
    _$v = other as _$ScheduledSegment;
  }

  @override
  void update(void Function(ScheduledSegmentBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ScheduledSegment build() => _build();

  _$ScheduledSegment _build() {
    ScheduledSegment._validate(this);
    _$ScheduledSegment _$result;
    try {
      _$result =
          _$v ??
          _$ScheduledSegment._(
            clip: clip.build(),
            start: BuiltValueNullFieldError.checkNotNull(
              start,
              r'ScheduledSegment',
              'start',
            ),
            end: BuiltValueNullFieldError.checkNotNull(
              end,
              r'ScheduledSegment',
              'end',
            ),
            programTime: programTime,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'clip';
        clip.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ScheduledSegment',
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
