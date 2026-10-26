// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quality_candidate.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$QualityCandidate extends QualityCandidate {
  @override
  final String label;
  @override
  final MediaSource source;
  @override
  final int? bitrate;
  @override
  final String? id;
  @override
  final Map<String, Object?> attributes;

  factory _$QualityCandidate([
    void Function(QualityCandidateBuilder)? updates,
  ]) => (QualityCandidateBuilder()..update(updates))._build();

  _$QualityCandidate._({
    required this.label,
    required this.source,
    this.bitrate,
    this.id,
    required this.attributes,
  }) : super._();
  @override
  QualityCandidate rebuild(void Function(QualityCandidateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  QualityCandidateBuilder toBuilder() =>
      QualityCandidateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is QualityCandidate &&
        label == other.label &&
        source == other.source &&
        bitrate == other.bitrate &&
        id == other.id &&
        attributes == other.attributes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, source.hashCode);
    _$hash = $jc(_$hash, bitrate.hashCode);
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, attributes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'QualityCandidate')
          ..add('label', label)
          ..add('source', source)
          ..add('bitrate', bitrate)
          ..add('id', id)
          ..add('attributes', attributes))
        .toString();
  }
}

class QualityCandidateBuilder
    implements Builder<QualityCandidate, QualityCandidateBuilder> {
  _$QualityCandidate? _$v;

  String? _label;
  String? get label => _$this._label;
  set label(String? label) => _$this._label = label;

  MediaSource? _source;
  MediaSource? get source => _$this._source;
  set source(MediaSource? source) => _$this._source = source;

  int? _bitrate;
  int? get bitrate => _$this._bitrate;
  set bitrate(int? bitrate) => _$this._bitrate = bitrate;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  Map<String, Object?>? _attributes;
  Map<String, Object?>? get attributes => _$this._attributes;
  set attributes(Map<String, Object?>? attributes) =>
      _$this._attributes = attributes;

  QualityCandidateBuilder() {
    QualityCandidate._initialize(this);
  }

  QualityCandidateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _label = $v.label;
      _source = $v.source;
      _bitrate = $v.bitrate;
      _id = $v.id;
      _attributes = $v.attributes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(QualityCandidate other) {
    _$v = other as _$QualityCandidate;
  }

  @override
  void update(void Function(QualityCandidateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  QualityCandidate build() => _build();

  _$QualityCandidate _build() {
    final _$result =
        _$v ??
        _$QualityCandidate._(
          label: BuiltValueNullFieldError.checkNotNull(
            label,
            r'QualityCandidate',
            'label',
          ),
          source: BuiltValueNullFieldError.checkNotNull(
            source,
            r'QualityCandidate',
            'source',
          ),
          bitrate: bitrate,
          id: id,
          attributes: BuiltValueNullFieldError.checkNotNull(
            attributes,
            r'QualityCandidate',
            'attributes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
