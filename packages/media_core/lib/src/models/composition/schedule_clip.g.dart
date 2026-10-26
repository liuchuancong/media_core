// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_clip.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ScheduleClip extends ScheduleClip {
  @override
  final MediaSource source;
  @override
  final Duration duration;
  @override
  final ClipKind kind;
  @override
  final String? id;
  @override
  final Duration? skipAfter;
  @override
  final Uri? clickThroughUrl;
  @override
  final List<Uri> trackingUris;
  @override
  final Map<String, Object?> attributes;

  factory _$ScheduleClip([void Function(ScheduleClipBuilder)? updates]) =>
      (ScheduleClipBuilder()..update(updates))._build();

  _$ScheduleClip._({
    required this.source,
    required this.duration,
    required this.kind,
    this.id,
    this.skipAfter,
    this.clickThroughUrl,
    required this.trackingUris,
    required this.attributes,
  }) : super._();
  @override
  ScheduleClip rebuild(void Function(ScheduleClipBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ScheduleClipBuilder toBuilder() => ScheduleClipBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ScheduleClip &&
        source == other.source &&
        duration == other.duration &&
        kind == other.kind &&
        id == other.id &&
        skipAfter == other.skipAfter &&
        clickThroughUrl == other.clickThroughUrl &&
        trackingUris == other.trackingUris &&
        attributes == other.attributes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, source.hashCode);
    _$hash = $jc(_$hash, duration.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, skipAfter.hashCode);
    _$hash = $jc(_$hash, clickThroughUrl.hashCode);
    _$hash = $jc(_$hash, trackingUris.hashCode);
    _$hash = $jc(_$hash, attributes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ScheduleClip')
          ..add('source', source)
          ..add('duration', duration)
          ..add('kind', kind)
          ..add('id', id)
          ..add('skipAfter', skipAfter)
          ..add('clickThroughUrl', clickThroughUrl)
          ..add('trackingUris', trackingUris)
          ..add('attributes', attributes))
        .toString();
  }
}

class ScheduleClipBuilder
    implements Builder<ScheduleClip, ScheduleClipBuilder> {
  _$ScheduleClip? _$v;

  MediaSource? _source;
  MediaSource? get source => _$this._source;
  set source(MediaSource? source) => _$this._source = source;

  Duration? _duration;
  Duration? get duration => _$this._duration;
  set duration(Duration? duration) => _$this._duration = duration;

  ClipKind? _kind;
  ClipKind? get kind => _$this._kind;
  set kind(ClipKind? kind) => _$this._kind = kind;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  Duration? _skipAfter;
  Duration? get skipAfter => _$this._skipAfter;
  set skipAfter(Duration? skipAfter) => _$this._skipAfter = skipAfter;

  Uri? _clickThroughUrl;
  Uri? get clickThroughUrl => _$this._clickThroughUrl;
  set clickThroughUrl(Uri? clickThroughUrl) =>
      _$this._clickThroughUrl = clickThroughUrl;

  List<Uri>? _trackingUris;
  List<Uri>? get trackingUris => _$this._trackingUris;
  set trackingUris(List<Uri>? trackingUris) =>
      _$this._trackingUris = trackingUris;

  Map<String, Object?>? _attributes;
  Map<String, Object?>? get attributes => _$this._attributes;
  set attributes(Map<String, Object?>? attributes) =>
      _$this._attributes = attributes;

  ScheduleClipBuilder() {
    ScheduleClip._initialize(this);
  }

  ScheduleClipBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _source = $v.source;
      _duration = $v.duration;
      _kind = $v.kind;
      _id = $v.id;
      _skipAfter = $v.skipAfter;
      _clickThroughUrl = $v.clickThroughUrl;
      _trackingUris = $v.trackingUris;
      _attributes = $v.attributes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ScheduleClip other) {
    _$v = other as _$ScheduleClip;
  }

  @override
  void update(void Function(ScheduleClipBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ScheduleClip build() => _build();

  _$ScheduleClip _build() {
    ScheduleClip._validate(this);
    final _$result =
        _$v ??
        _$ScheduleClip._(
          source: BuiltValueNullFieldError.checkNotNull(
            source,
            r'ScheduleClip',
            'source',
          ),
          duration: BuiltValueNullFieldError.checkNotNull(
            duration,
            r'ScheduleClip',
            'duration',
          ),
          kind: BuiltValueNullFieldError.checkNotNull(
            kind,
            r'ScheduleClip',
            'kind',
          ),
          id: id,
          skipAfter: skipAfter,
          clickThroughUrl: clickThroughUrl,
          trackingUris: BuiltValueNullFieldError.checkNotNull(
            trackingUris,
            r'ScheduleClip',
            'trackingUris',
          ),
          attributes: BuiltValueNullFieldError.checkNotNull(
            attributes,
            r'ScheduleClip',
            'attributes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
