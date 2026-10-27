// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_source.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerSource extends PlayerSource {
  @override
  final SourceId id;
  @override
  final Uri uri;
  @override
  final SourceType type;
  @override
  final SourceProtocol protocol;
  @override
  final SourceMediaType mediaType;
  @override
  final SourceFormat format;
  @override
  final SourceHeaders? headers;
  @override
  final String? title;
  @override
  final Map<String, Object?> metadata;
  @override
  final DateTime? createdAt;

  factory _$PlayerSource([void Function(PlayerSourceBuilder)? updates]) =>
      (PlayerSourceBuilder()..update(updates))._build();

  _$PlayerSource._({
    required this.id,
    required this.uri,
    required this.type,
    required this.protocol,
    required this.mediaType,
    required this.format,
    this.headers,
    this.title,
    required this.metadata,
    this.createdAt,
  }) : super._();
  @override
  PlayerSource rebuild(void Function(PlayerSourceBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlayerSourceBuilder toBuilder() => PlayerSourceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerSource &&
        id == other.id &&
        uri == other.uri &&
        type == other.type &&
        protocol == other.protocol &&
        mediaType == other.mediaType &&
        format == other.format &&
        headers == other.headers &&
        title == other.title &&
        metadata == other.metadata &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, uri.hashCode);
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, protocol.hashCode);
    _$hash = $jc(_$hash, mediaType.hashCode);
    _$hash = $jc(_$hash, format.hashCode);
    _$hash = $jc(_$hash, headers.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, metadata.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerSource')
          ..add('id', id)
          ..add('uri', uri)
          ..add('type', type)
          ..add('protocol', protocol)
          ..add('mediaType', mediaType)
          ..add('format', format)
          ..add('headers', headers)
          ..add('title', title)
          ..add('metadata', metadata)
          ..add('createdAt', createdAt))
        .toString();
  }
}

class PlayerSourceBuilder
    implements Builder<PlayerSource, PlayerSourceBuilder> {
  _$PlayerSource? _$v;

  SourceId? _id;
  SourceId? get id => _$this._id;
  set id(SourceId? id) => _$this._id = id;

  Uri? _uri;
  Uri? get uri => _$this._uri;
  set uri(Uri? uri) => _$this._uri = uri;

  SourceType? _type;
  SourceType? get type => _$this._type;
  set type(SourceType? type) => _$this._type = type;

  SourceProtocol? _protocol;
  SourceProtocol? get protocol => _$this._protocol;
  set protocol(SourceProtocol? protocol) => _$this._protocol = protocol;

  SourceMediaType? _mediaType;
  SourceMediaType? get mediaType => _$this._mediaType;
  set mediaType(SourceMediaType? mediaType) => _$this._mediaType = mediaType;

  SourceFormat? _format;
  SourceFormat? get format => _$this._format;
  set format(SourceFormat? format) => _$this._format = format;

  SourceHeaders? _headers;
  SourceHeaders? get headers => _$this._headers;
  set headers(SourceHeaders? headers) => _$this._headers = headers;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  Map<String, Object?>? _metadata;
  Map<String, Object?>? get metadata => _$this._metadata;
  set metadata(Map<String, Object?>? metadata) => _$this._metadata = metadata;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  PlayerSourceBuilder() {
    PlayerSource._initialize(this);
  }

  PlayerSourceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _uri = $v.uri;
      _type = $v.type;
      _protocol = $v.protocol;
      _mediaType = $v.mediaType;
      _format = $v.format;
      _headers = $v.headers;
      _title = $v.title;
      _metadata = $v.metadata;
      _createdAt = $v.createdAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerSource other) {
    _$v = other as _$PlayerSource;
  }

  @override
  void update(void Function(PlayerSourceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerSource build() => _build();

  _$PlayerSource _build() {
    final _$result =
        _$v ??
        _$PlayerSource._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'PlayerSource', 'id'),
          uri: BuiltValueNullFieldError.checkNotNull(
            uri,
            r'PlayerSource',
            'uri',
          ),
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'PlayerSource',
            'type',
          ),
          protocol: BuiltValueNullFieldError.checkNotNull(
            protocol,
            r'PlayerSource',
            'protocol',
          ),
          mediaType: BuiltValueNullFieldError.checkNotNull(
            mediaType,
            r'PlayerSource',
            'mediaType',
          ),
          format: BuiltValueNullFieldError.checkNotNull(
            format,
            r'PlayerSource',
            'format',
          ),
          headers: headers,
          title: title,
          metadata: BuiltValueNullFieldError.checkNotNull(
            metadata,
            r'PlayerSource',
            'metadata',
          ),
          createdAt: createdAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
