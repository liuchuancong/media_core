// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_timeline.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$MediaTimeline extends MediaTimeline {
  @override
  final List<TimelineTrack> tracks;
  @override
  final Duration originShift;
  @override
  final List<MediaSegment> segments;
  @override
  final List<MediaCue> cues;

  factory _$MediaTimeline([void Function(MediaTimelineBuilder)? updates]) =>
      (MediaTimelineBuilder()..update(updates))._build();

  _$MediaTimeline._({
    required this.tracks,
    required this.originShift,
    required this.segments,
    required this.cues,
  }) : super._();
  @override
  MediaTimeline rebuild(void Function(MediaTimelineBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MediaTimelineBuilder toBuilder() => MediaTimelineBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MediaTimeline &&
        tracks == other.tracks &&
        originShift == other.originShift &&
        segments == other.segments &&
        cues == other.cues;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, tracks.hashCode);
    _$hash = $jc(_$hash, originShift.hashCode);
    _$hash = $jc(_$hash, segments.hashCode);
    _$hash = $jc(_$hash, cues.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MediaTimeline')
          ..add('tracks', tracks)
          ..add('originShift', originShift)
          ..add('segments', segments)
          ..add('cues', cues))
        .toString();
  }
}

class MediaTimelineBuilder
    implements Builder<MediaTimeline, MediaTimelineBuilder> {
  _$MediaTimeline? _$v;

  List<TimelineTrack>? _tracks;
  List<TimelineTrack>? get tracks => _$this._tracks;
  set tracks(List<TimelineTrack>? tracks) => _$this._tracks = tracks;

  Duration? _originShift;
  Duration? get originShift => _$this._originShift;
  set originShift(Duration? originShift) => _$this._originShift = originShift;

  List<MediaSegment>? _segments;
  List<MediaSegment>? get segments => _$this._segments;
  set segments(List<MediaSegment>? segments) => _$this._segments = segments;

  List<MediaCue>? _cues;
  List<MediaCue>? get cues => _$this._cues;
  set cues(List<MediaCue>? cues) => _$this._cues = cues;

  MediaTimelineBuilder() {
    MediaTimeline._initialize(this);
  }

  MediaTimelineBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _tracks = $v.tracks;
      _originShift = $v.originShift;
      _segments = $v.segments;
      _cues = $v.cues;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MediaTimeline other) {
    _$v = other as _$MediaTimeline;
  }

  @override
  void update(void Function(MediaTimelineBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MediaTimeline build() => _build();

  _$MediaTimeline _build() {
    final _$result =
        _$v ??
        _$MediaTimeline._(
          tracks: BuiltValueNullFieldError.checkNotNull(
            tracks,
            r'MediaTimeline',
            'tracks',
          ),
          originShift: BuiltValueNullFieldError.checkNotNull(
            originShift,
            r'MediaTimeline',
            'originShift',
          ),
          segments: BuiltValueNullFieldError.checkNotNull(
            segments,
            r'MediaTimeline',
            'segments',
          ),
          cues: BuiltValueNullFieldError.checkNotNull(
            cues,
            r'MediaTimeline',
            'cues',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
