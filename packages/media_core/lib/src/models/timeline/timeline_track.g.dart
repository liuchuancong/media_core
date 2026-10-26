// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_track.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$TimelineTrack extends TimelineTrack {
  @override
  final MediaTrack track;
  @override
  final Duration offset;

  factory _$TimelineTrack([void Function(TimelineTrackBuilder)? updates]) =>
      (TimelineTrackBuilder()..update(updates))._build();

  _$TimelineTrack._({required this.track, required this.offset}) : super._();
  @override
  TimelineTrack rebuild(void Function(TimelineTrackBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TimelineTrackBuilder toBuilder() => TimelineTrackBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TimelineTrack &&
        track == other.track &&
        offset == other.offset;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, track.hashCode);
    _$hash = $jc(_$hash, offset.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'TimelineTrack')
          ..add('track', track)
          ..add('offset', offset))
        .toString();
  }
}

class TimelineTrackBuilder
    implements Builder<TimelineTrack, TimelineTrackBuilder> {
  _$TimelineTrack? _$v;

  MediaTrackBuilder? _track;
  MediaTrackBuilder get track => _$this._track ??= MediaTrackBuilder();
  set track(MediaTrackBuilder? track) => _$this._track = track;

  Duration? _offset;
  Duration? get offset => _$this._offset;
  set offset(Duration? offset) => _$this._offset = offset;

  TimelineTrackBuilder() {
    TimelineTrack._initialize(this);
  }

  TimelineTrackBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _track = $v.track.toBuilder();
      _offset = $v.offset;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(TimelineTrack other) {
    _$v = other as _$TimelineTrack;
  }

  @override
  void update(void Function(TimelineTrackBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  TimelineTrack build() => _build();

  _$TimelineTrack _build() {
    _$TimelineTrack _$result;
    try {
      _$result =
          _$v ??
          _$TimelineTrack._(
            track: track.build(),
            offset: BuiltValueNullFieldError.checkNotNull(
              offset,
              r'TimelineTrack',
              'offset',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'track';
        track.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'TimelineTrack',
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
