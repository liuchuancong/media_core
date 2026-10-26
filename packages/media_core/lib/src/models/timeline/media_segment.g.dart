// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_segment.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$MediaSegment extends MediaSegment {
  @override
  final Duration start;
  @override
  final Duration duration;
  @override
  final String? label;
  @override
  final Map<String, Object?> attributes;

  factory _$MediaSegment([void Function(MediaSegmentBuilder)? updates]) =>
      (MediaSegmentBuilder()..update(updates))._build();

  _$MediaSegment._({
    required this.start,
    required this.duration,
    this.label,
    required this.attributes,
  }) : super._();
  @override
  MediaSegment rebuild(void Function(MediaSegmentBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MediaSegmentBuilder toBuilder() => MediaSegmentBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MediaSegment &&
        start == other.start &&
        duration == other.duration &&
        label == other.label &&
        attributes == other.attributes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, start.hashCode);
    _$hash = $jc(_$hash, duration.hashCode);
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, attributes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MediaSegment')
          ..add('start', start)
          ..add('duration', duration)
          ..add('label', label)
          ..add('attributes', attributes))
        .toString();
  }
}

class MediaSegmentBuilder
    implements Builder<MediaSegment, MediaSegmentBuilder> {
  _$MediaSegment? _$v;

  Duration? _start;
  Duration? get start => _$this._start;
  set start(Duration? start) => _$this._start = start;

  Duration? _duration;
  Duration? get duration => _$this._duration;
  set duration(Duration? duration) => _$this._duration = duration;

  String? _label;
  String? get label => _$this._label;
  set label(String? label) => _$this._label = label;

  Map<String, Object?>? _attributes;
  Map<String, Object?>? get attributes => _$this._attributes;
  set attributes(Map<String, Object?>? attributes) =>
      _$this._attributes = attributes;

  MediaSegmentBuilder() {
    MediaSegment._initialize(this);
  }

  MediaSegmentBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _start = $v.start;
      _duration = $v.duration;
      _label = $v.label;
      _attributes = $v.attributes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MediaSegment other) {
    _$v = other as _$MediaSegment;
  }

  @override
  void update(void Function(MediaSegmentBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MediaSegment build() => _build();

  _$MediaSegment _build() {
    MediaSegment._validate(this);
    final _$result =
        _$v ??
        _$MediaSegment._(
          start: BuiltValueNullFieldError.checkNotNull(
            start,
            r'MediaSegment',
            'start',
          ),
          duration: BuiltValueNullFieldError.checkNotNull(
            duration,
            r'MediaSegment',
            'duration',
          ),
          label: label,
          attributes: BuiltValueNullFieldError.checkNotNull(
            attributes,
            r'MediaSegment',
            'attributes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
