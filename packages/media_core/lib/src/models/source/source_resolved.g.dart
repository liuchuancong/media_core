// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_resolved.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResolvedSource extends ResolvedSource {
  @override
  final SourceId sourceId;
  @override
  final Uri uri;
  @override
  final SourceProtocol protocol;
  @override
  final SourceMediaType mediaType;
  @override
  final SourceFormat format;
  @override
  final SourceHeaders? headers;
  @override
  final PlayerSource? source;
  @override
  final Map<String, Object?> metadata;

  factory _$ResolvedSource([void Function(ResolvedSourceBuilder)? updates]) =>
      (ResolvedSourceBuilder()..update(updates))._build();

  _$ResolvedSource._({
    required this.sourceId,
    required this.uri,
    required this.protocol,
    required this.mediaType,
    required this.format,
    this.headers,
    this.source,
    required this.metadata,
  }) : super._();
  @override
  ResolvedSource rebuild(void Function(ResolvedSourceBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ResolvedSourceBuilder toBuilder() => ResolvedSourceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResolvedSource &&
        sourceId == other.sourceId &&
        uri == other.uri &&
        protocol == other.protocol &&
        mediaType == other.mediaType &&
        format == other.format &&
        headers == other.headers &&
        source == other.source &&
        metadata == other.metadata;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, sourceId.hashCode);
    _$hash = $jc(_$hash, uri.hashCode);
    _$hash = $jc(_$hash, protocol.hashCode);
    _$hash = $jc(_$hash, mediaType.hashCode);
    _$hash = $jc(_$hash, format.hashCode);
    _$hash = $jc(_$hash, headers.hashCode);
    _$hash = $jc(_$hash, source.hashCode);
    _$hash = $jc(_$hash, metadata.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ResolvedSource')
          ..add('sourceId', sourceId)
          ..add('uri', uri)
          ..add('protocol', protocol)
          ..add('mediaType', mediaType)
          ..add('format', format)
          ..add('headers', headers)
          ..add('source', source)
          ..add('metadata', metadata))
        .toString();
  }
}

class ResolvedSourceBuilder
    implements Builder<ResolvedSource, ResolvedSourceBuilder> {
  _$ResolvedSource? _$v;

  SourceId? _sourceId;
  SourceId? get sourceId => _$this._sourceId;
  set sourceId(SourceId? sourceId) => _$this._sourceId = sourceId;

  Uri? _uri;
  Uri? get uri => _$this._uri;
  set uri(Uri? uri) => _$this._uri = uri;

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

  PlayerSource? _source;
  PlayerSource? get source => _$this._source;
  set source(PlayerSource? source) => _$this._source = source;

  Map<String, Object?>? _metadata;
  Map<String, Object?>? get metadata => _$this._metadata;
  set metadata(Map<String, Object?>? metadata) => _$this._metadata = metadata;

  ResolvedSourceBuilder() {
    ResolvedSource._initialize(this);
  }

  ResolvedSourceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _sourceId = $v.sourceId;
      _uri = $v.uri;
      _protocol = $v.protocol;
      _mediaType = $v.mediaType;
      _format = $v.format;
      _headers = $v.headers;
      _source = $v.source;
      _metadata = $v.metadata;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResolvedSource other) {
    _$v = other as _$ResolvedSource;
  }

  @override
  void update(void Function(ResolvedSourceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResolvedSource build() => _build();

  _$ResolvedSource _build() {
    final _$result =
        _$v ??
        _$ResolvedSource._(
          sourceId: BuiltValueNullFieldError.checkNotNull(
            sourceId,
            r'ResolvedSource',
            'sourceId',
          ),
          uri: BuiltValueNullFieldError.checkNotNull(
            uri,
            r'ResolvedSource',
            'uri',
          ),
          protocol: BuiltValueNullFieldError.checkNotNull(
            protocol,
            r'ResolvedSource',
            'protocol',
          ),
          mediaType: BuiltValueNullFieldError.checkNotNull(
            mediaType,
            r'ResolvedSource',
            'mediaType',
          ),
          format: BuiltValueNullFieldError.checkNotNull(
            format,
            r'ResolvedSource',
            'format',
          ),
          headers: headers,
          source: source,
          metadata: BuiltValueNullFieldError.checkNotNull(
            metadata,
            r'ResolvedSource',
            'metadata',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
