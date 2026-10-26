// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_schedule.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlaybackSchedule extends PlaybackSchedule {
  @override
  final ScheduleClip program;
  @override
  final List<MediaBreak> breaks;

  factory _$PlaybackSchedule([
    void Function(PlaybackScheduleBuilder)? updates,
  ]) => (PlaybackScheduleBuilder()..update(updates))._build();

  _$PlaybackSchedule._({required this.program, required this.breaks})
    : super._();
  @override
  PlaybackSchedule rebuild(void Function(PlaybackScheduleBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlaybackScheduleBuilder toBuilder() =>
      PlaybackScheduleBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlaybackSchedule &&
        program == other.program &&
        breaks == other.breaks;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, program.hashCode);
    _$hash = $jc(_$hash, breaks.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlaybackSchedule')
          ..add('program', program)
          ..add('breaks', breaks))
        .toString();
  }
}

class PlaybackScheduleBuilder
    implements Builder<PlaybackSchedule, PlaybackScheduleBuilder> {
  _$PlaybackSchedule? _$v;

  ScheduleClipBuilder? _program;
  ScheduleClipBuilder get program => _$this._program ??= ScheduleClipBuilder();
  set program(ScheduleClipBuilder? program) => _$this._program = program;

  List<MediaBreak>? _breaks;
  List<MediaBreak>? get breaks => _$this._breaks;
  set breaks(List<MediaBreak>? breaks) => _$this._breaks = breaks;

  PlaybackScheduleBuilder() {
    PlaybackSchedule._initialize(this);
  }

  PlaybackScheduleBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _program = $v.program.toBuilder();
      _breaks = $v.breaks;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlaybackSchedule other) {
    _$v = other as _$PlaybackSchedule;
  }

  @override
  void update(void Function(PlaybackScheduleBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlaybackSchedule build() => _build();

  _$PlaybackSchedule _build() {
    PlaybackSchedule._validate(this);
    _$PlaybackSchedule _$result;
    try {
      _$result =
          _$v ??
          _$PlaybackSchedule._(
            program: program.build(),
            breaks: BuiltValueNullFieldError.checkNotNull(
              breaks,
              r'PlaybackSchedule',
              'breaks',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'program';
        program.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PlaybackSchedule',
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
