// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_metadata.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SourceMetadata extends SourceMetadata {
  @override
  final String? title;
  @override
  final String? description;
  @override
  final String? author;
  @override
  final String? channel;
  @override
  final String? language;
  @override
  final Uri? artwork;
  @override
  final Duration? duration;
  @override
  final Map<String, Object?> extras;

  factory _$SourceMetadata([void Function(SourceMetadataBuilder)? updates]) =>
      (SourceMetadataBuilder()..update(updates))._build();

  _$SourceMetadata._({
    this.title,
    this.description,
    this.author,
    this.channel,
    this.language,
    this.artwork,
    this.duration,
    required this.extras,
  }) : super._();
  @override
  SourceMetadata rebuild(void Function(SourceMetadataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SourceMetadataBuilder toBuilder() => SourceMetadataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SourceMetadata &&
        title == other.title &&
        description == other.description &&
        author == other.author &&
        channel == other.channel &&
        language == other.language &&
        artwork == other.artwork &&
        duration == other.duration &&
        extras == other.extras;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, author.hashCode);
    _$hash = $jc(_$hash, channel.hashCode);
    _$hash = $jc(_$hash, language.hashCode);
    _$hash = $jc(_$hash, artwork.hashCode);
    _$hash = $jc(_$hash, duration.hashCode);
    _$hash = $jc(_$hash, extras.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SourceMetadata')
          ..add('title', title)
          ..add('description', description)
          ..add('author', author)
          ..add('channel', channel)
          ..add('language', language)
          ..add('artwork', artwork)
          ..add('duration', duration)
          ..add('extras', extras))
        .toString();
  }
}

class SourceMetadataBuilder
    implements Builder<SourceMetadata, SourceMetadataBuilder> {
  _$SourceMetadata? _$v;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  String? _author;
  String? get author => _$this._author;
  set author(String? author) => _$this._author = author;

  String? _channel;
  String? get channel => _$this._channel;
  set channel(String? channel) => _$this._channel = channel;

  String? _language;
  String? get language => _$this._language;
  set language(String? language) => _$this._language = language;

  Uri? _artwork;
  Uri? get artwork => _$this._artwork;
  set artwork(Uri? artwork) => _$this._artwork = artwork;

  Duration? _duration;
  Duration? get duration => _$this._duration;
  set duration(Duration? duration) => _$this._duration = duration;

  Map<String, Object?>? _extras;
  Map<String, Object?>? get extras => _$this._extras;
  set extras(Map<String, Object?>? extras) => _$this._extras = extras;

  SourceMetadataBuilder() {
    SourceMetadata._initialize(this);
  }

  SourceMetadataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _title = $v.title;
      _description = $v.description;
      _author = $v.author;
      _channel = $v.channel;
      _language = $v.language;
      _artwork = $v.artwork;
      _duration = $v.duration;
      _extras = $v.extras;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SourceMetadata other) {
    _$v = other as _$SourceMetadata;
  }

  @override
  void update(void Function(SourceMetadataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SourceMetadata build() => _build();

  _$SourceMetadata _build() {
    final _$result =
        _$v ??
        _$SourceMetadata._(
          title: title,
          description: description,
          author: author,
          channel: channel,
          language: language,
          artwork: artwork,
          duration: duration,
          extras: BuiltValueNullFieldError.checkNotNull(
            extras,
            r'SourceMetadata',
            'extras',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
