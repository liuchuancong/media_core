// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_break.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$MediaBreak extends MediaBreak {
  @override
  final BreakPosition position;
  @override
  final List<ScheduleClip> clips;

  factory _$MediaBreak([void Function(MediaBreakBuilder)? updates]) =>
      (MediaBreakBuilder()..update(updates))._build();

  _$MediaBreak._({required this.position, required this.clips}) : super._();
  @override
  MediaBreak rebuild(void Function(MediaBreakBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MediaBreakBuilder toBuilder() => MediaBreakBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MediaBreak &&
        position == other.position &&
        clips == other.clips;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, position.hashCode);
    _$hash = $jc(_$hash, clips.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MediaBreak')
          ..add('position', position)
          ..add('clips', clips))
        .toString();
  }
}

class MediaBreakBuilder implements Builder<MediaBreak, MediaBreakBuilder> {
  _$MediaBreak? _$v;

  BreakPosition? _position;
  BreakPosition? get position => _$this._position;
  set position(BreakPosition? position) => _$this._position = position;

  List<ScheduleClip>? _clips;
  List<ScheduleClip>? get clips => _$this._clips;
  set clips(List<ScheduleClip>? clips) => _$this._clips = clips;

  MediaBreakBuilder();

  MediaBreakBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _position = $v.position;
      _clips = $v.clips;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MediaBreak other) {
    _$v = other as _$MediaBreak;
  }

  @override
  void update(void Function(MediaBreakBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MediaBreak build() => _build();

  _$MediaBreak _build() {
    MediaBreak._validate(this);
    final _$result =
        _$v ??
        _$MediaBreak._(
          position: BuiltValueNullFieldError.checkNotNull(
            position,
            r'MediaBreak',
            'position',
          ),
          clips: BuiltValueNullFieldError.checkNotNull(
            clips,
            r'MediaBreak',
            'clips',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
