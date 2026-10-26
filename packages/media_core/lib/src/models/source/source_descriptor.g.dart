// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_descriptor.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SourceDescriptor extends SourceDescriptor {
  @override
  final SourceId id;
  @override
  final SourceLocation location;
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
  final SourceMetadata? metadata;
  @override
  final bool live;
  @override
  final bool seekable;
  @override
  final int priority;
  @override
  final Map<String, Object?> attributes;

  factory _$SourceDescriptor([
    void Function(SourceDescriptorBuilder)? updates,
  ]) => (SourceDescriptorBuilder()..update(updates))._build();

  _$SourceDescriptor._({
    required this.id,
    required this.location,
    required this.type,
    required this.protocol,
    required this.mediaType,
    required this.format,
    this.headers,
    this.metadata,
    required this.live,
    required this.seekable,
    required this.priority,
    required this.attributes,
  }) : super._();
  @override
  SourceDescriptor rebuild(void Function(SourceDescriptorBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SourceDescriptorBuilder toBuilder() =>
      SourceDescriptorBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SourceDescriptor &&
        id == other.id &&
        location == other.location &&
        type == other.type &&
        protocol == other.protocol &&
        mediaType == other.mediaType &&
        format == other.format &&
        headers == other.headers &&
        metadata == other.metadata &&
        live == other.live &&
        seekable == other.seekable &&
        priority == other.priority &&
        attributes == other.attributes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, location.hashCode);
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, protocol.hashCode);
    _$hash = $jc(_$hash, mediaType.hashCode);
    _$hash = $jc(_$hash, format.hashCode);
    _$hash = $jc(_$hash, headers.hashCode);
    _$hash = $jc(_$hash, metadata.hashCode);
    _$hash = $jc(_$hash, live.hashCode);
    _$hash = $jc(_$hash, seekable.hashCode);
    _$hash = $jc(_$hash, priority.hashCode);
    _$hash = $jc(_$hash, attributes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SourceDescriptor')
          ..add('id', id)
          ..add('location', location)
          ..add('type', type)
          ..add('protocol', protocol)
          ..add('mediaType', mediaType)
          ..add('format', format)
          ..add('headers', headers)
          ..add('metadata', metadata)
          ..add('live', live)
          ..add('seekable', seekable)
          ..add('priority', priority)
          ..add('attributes', attributes))
        .toString();
  }
}

class SourceDescriptorBuilder
    implements Builder<SourceDescriptor, SourceDescriptorBuilder> {
  _$SourceDescriptor? _$v;

  SourceId? _id;
  SourceId? get id => _$this._id;
  set id(SourceId? id) => _$this._id = id;

  SourceLocationBuilder? _location;
  SourceLocationBuilder get location =>
      _$this._location ??= SourceLocationBuilder();
  set location(SourceLocationBuilder? location) => _$this._location = location;

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

  SourceMetadataBuilder? _metadata;
  SourceMetadataBuilder get metadata =>
      _$this._metadata ??= SourceMetadataBuilder();
  set metadata(SourceMetadataBuilder? metadata) => _$this._metadata = metadata;

  bool? _live;
  bool? get live => _$this._live;
  set live(bool? live) => _$this._live = live;

  bool? _seekable;
  bool? get seekable => _$this._seekable;
  set seekable(bool? seekable) => _$this._seekable = seekable;

  int? _priority;
  int? get priority => _$this._priority;
  set priority(int? priority) => _$this._priority = priority;

  Map<String, Object?>? _attributes;
  Map<String, Object?>? get attributes => _$this._attributes;
  set attributes(Map<String, Object?>? attributes) =>
      _$this._attributes = attributes;

  SourceDescriptorBuilder() {
    SourceDescriptor._initialize(this);
  }

  SourceDescriptorBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _location = $v.location.toBuilder();
      _type = $v.type;
      _protocol = $v.protocol;
      _mediaType = $v.mediaType;
      _format = $v.format;
      _headers = $v.headers;
      _metadata = $v.metadata?.toBuilder();
      _live = $v.live;
      _seekable = $v.seekable;
      _priority = $v.priority;
      _attributes = $v.attributes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SourceDescriptor other) {
    _$v = other as _$SourceDescriptor;
  }

  @override
  void update(void Function(SourceDescriptorBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SourceDescriptor build() => _build();

  _$SourceDescriptor _build() {
    _$SourceDescriptor _$result;
    try {
      _$result =
          _$v ??
          _$SourceDescriptor._(
            id: BuiltValueNullFieldError.checkNotNull(
              id,
              r'SourceDescriptor',
              'id',
            ),
            location: location.build(),
            type: BuiltValueNullFieldError.checkNotNull(
              type,
              r'SourceDescriptor',
              'type',
            ),
            protocol: BuiltValueNullFieldError.checkNotNull(
              protocol,
              r'SourceDescriptor',
              'protocol',
            ),
            mediaType: BuiltValueNullFieldError.checkNotNull(
              mediaType,
              r'SourceDescriptor',
              'mediaType',
            ),
            format: BuiltValueNullFieldError.checkNotNull(
              format,
              r'SourceDescriptor',
              'format',
            ),
            headers: headers,
            metadata: _metadata?.build(),
            live: BuiltValueNullFieldError.checkNotNull(
              live,
              r'SourceDescriptor',
              'live',
            ),
            seekable: BuiltValueNullFieldError.checkNotNull(
              seekable,
              r'SourceDescriptor',
              'seekable',
            ),
            priority: BuiltValueNullFieldError.checkNotNull(
              priority,
              r'SourceDescriptor',
              'priority',
            ),
            attributes: BuiltValueNullFieldError.checkNotNull(
              attributes,
              r'SourceDescriptor',
              'attributes',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'location';
        location.build();

        _$failedField = 'metadata';
        _metadata?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SourceDescriptor',
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
