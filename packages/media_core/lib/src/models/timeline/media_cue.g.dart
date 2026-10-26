// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_cue.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$MediaCue extends MediaCue {
  @override
  final Duration start;
  @override
  final Duration end;
  @override
  final String text;
  @override
  final String? id;
  @override
  final String? language;
  @override
  final Map<String, Object?> attributes;

  factory _$MediaCue([void Function(MediaCueBuilder)? updates]) =>
      (MediaCueBuilder()..update(updates))._build();

  _$MediaCue._({
    required this.start,
    required this.end,
    required this.text,
    this.id,
    this.language,
    required this.attributes,
  }) : super._();
  @override
  MediaCue rebuild(void Function(MediaCueBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MediaCueBuilder toBuilder() => MediaCueBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MediaCue &&
        start == other.start &&
        end == other.end &&
        text == other.text &&
        id == other.id &&
        language == other.language &&
        attributes == other.attributes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, start.hashCode);
    _$hash = $jc(_$hash, end.hashCode);
    _$hash = $jc(_$hash, text.hashCode);
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, language.hashCode);
    _$hash = $jc(_$hash, attributes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MediaCue')
          ..add('start', start)
          ..add('end', end)
          ..add('text', text)
          ..add('id', id)
          ..add('language', language)
          ..add('attributes', attributes))
        .toString();
  }
}

class MediaCueBuilder implements Builder<MediaCue, MediaCueBuilder> {
  _$MediaCue? _$v;

  Duration? _start;
  Duration? get start => _$this._start;
  set start(Duration? start) => _$this._start = start;

  Duration? _end;
  Duration? get end => _$this._end;
  set end(Duration? end) => _$this._end = end;

  String? _text;
  String? get text => _$this._text;
  set text(String? text) => _$this._text = text;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _language;
  String? get language => _$this._language;
  set language(String? language) => _$this._language = language;

  Map<String, Object?>? _attributes;
  Map<String, Object?>? get attributes => _$this._attributes;
  set attributes(Map<String, Object?>? attributes) =>
      _$this._attributes = attributes;

  MediaCueBuilder() {
    MediaCue._initialize(this);
  }

  MediaCueBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _start = $v.start;
      _end = $v.end;
      _text = $v.text;
      _id = $v.id;
      _language = $v.language;
      _attributes = $v.attributes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MediaCue other) {
    _$v = other as _$MediaCue;
  }

  @override
  void update(void Function(MediaCueBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MediaCue build() => _build();

  _$MediaCue _build() {
    MediaCue._validate(this);
    final _$result =
        _$v ??
        _$MediaCue._(
          start: BuiltValueNullFieldError.checkNotNull(
            start,
            r'MediaCue',
            'start',
          ),
          end: BuiltValueNullFieldError.checkNotNull(end, r'MediaCue', 'end'),
          text: BuiltValueNullFieldError.checkNotNull(
            text,
            r'MediaCue',
            'text',
          ),
          id: id,
          language: language,
          attributes: BuiltValueNullFieldError.checkNotNull(
            attributes,
            r'MediaCue',
            'attributes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
