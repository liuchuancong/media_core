// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_track.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$MediaTrack extends MediaTrack {
  @override
  final Uri uri;
  @override
  final MediaTrackType kind;
  @override
  final SourceHeaders? headers;
  @override
  final String? mimeType;
  @override
  final String? codec;
  @override
  final int? bitrate;
  @override
  final String? language;
  @override
  final Duration? startOffset;
  @override
  final Map<String, Object?> metadata;

  factory _$MediaTrack([void Function(MediaTrackBuilder)? updates]) =>
      (MediaTrackBuilder()..update(updates))._build();

  _$MediaTrack._({
    required this.uri,
    required this.kind,
    this.headers,
    this.mimeType,
    this.codec,
    this.bitrate,
    this.language,
    this.startOffset,
    required this.metadata,
  }) : super._();
  @override
  MediaTrack rebuild(void Function(MediaTrackBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MediaTrackBuilder toBuilder() => MediaTrackBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MediaTrack &&
        uri == other.uri &&
        kind == other.kind &&
        headers == other.headers &&
        mimeType == other.mimeType &&
        codec == other.codec &&
        bitrate == other.bitrate &&
        language == other.language &&
        startOffset == other.startOffset &&
        metadata == other.metadata;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, uri.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, headers.hashCode);
    _$hash = $jc(_$hash, mimeType.hashCode);
    _$hash = $jc(_$hash, codec.hashCode);
    _$hash = $jc(_$hash, bitrate.hashCode);
    _$hash = $jc(_$hash, language.hashCode);
    _$hash = $jc(_$hash, startOffset.hashCode);
    _$hash = $jc(_$hash, metadata.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MediaTrack')
          ..add('uri', uri)
          ..add('kind', kind)
          ..add('headers', headers)
          ..add('mimeType', mimeType)
          ..add('codec', codec)
          ..add('bitrate', bitrate)
          ..add('language', language)
          ..add('startOffset', startOffset)
          ..add('metadata', metadata))
        .toString();
  }
}

class MediaTrackBuilder implements Builder<MediaTrack, MediaTrackBuilder> {
  _$MediaTrack? _$v;

  Uri? _uri;
  Uri? get uri => _$this._uri;
  set uri(Uri? uri) => _$this._uri = uri;

  MediaTrackType? _kind;
  MediaTrackType? get kind => _$this._kind;
  set kind(MediaTrackType? kind) => _$this._kind = kind;

  SourceHeaders? _headers;
  SourceHeaders? get headers => _$this._headers;
  set headers(SourceHeaders? headers) => _$this._headers = headers;

  String? _mimeType;
  String? get mimeType => _$this._mimeType;
  set mimeType(String? mimeType) => _$this._mimeType = mimeType;

  String? _codec;
  String? get codec => _$this._codec;
  set codec(String? codec) => _$this._codec = codec;

  int? _bitrate;
  int? get bitrate => _$this._bitrate;
  set bitrate(int? bitrate) => _$this._bitrate = bitrate;

  String? _language;
  String? get language => _$this._language;
  set language(String? language) => _$this._language = language;

  Duration? _startOffset;
  Duration? get startOffset => _$this._startOffset;
  set startOffset(Duration? startOffset) => _$this._startOffset = startOffset;

  Map<String, Object?>? _metadata;
  Map<String, Object?>? get metadata => _$this._metadata;
  set metadata(Map<String, Object?>? metadata) => _$this._metadata = metadata;

  MediaTrackBuilder() {
    MediaTrack._initialize(this);
  }

  MediaTrackBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _uri = $v.uri;
      _kind = $v.kind;
      _headers = $v.headers;
      _mimeType = $v.mimeType;
      _codec = $v.codec;
      _bitrate = $v.bitrate;
      _language = $v.language;
      _startOffset = $v.startOffset;
      _metadata = $v.metadata;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MediaTrack other) {
    _$v = other as _$MediaTrack;
  }

  @override
  void update(void Function(MediaTrackBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MediaTrack build() => _build();

  _$MediaTrack _build() {
    final _$result =
        _$v ??
        _$MediaTrack._(
          uri: BuiltValueNullFieldError.checkNotNull(uri, r'MediaTrack', 'uri'),
          kind: BuiltValueNullFieldError.checkNotNull(
            kind,
            r'MediaTrack',
            'kind',
          ),
          headers: headers,
          mimeType: mimeType,
          codec: codec,
          bitrate: bitrate,
          language: language,
          startOffset: startOffset,
          metadata: BuiltValueNullFieldError.checkNotNull(
            metadata,
            r'MediaTrack',
            'metadata',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
