// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thumbnail_track.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ThumbnailTrack extends ThumbnailTrack {
  @override
  final List<Thumbnail> thumbnails;

  factory _$ThumbnailTrack([void Function(ThumbnailTrackBuilder)? updates]) =>
      (ThumbnailTrackBuilder()..update(updates))._build();

  _$ThumbnailTrack._({required this.thumbnails}) : super._();
  @override
  ThumbnailTrack rebuild(void Function(ThumbnailTrackBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ThumbnailTrackBuilder toBuilder() => ThumbnailTrackBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ThumbnailTrack && thumbnails == other.thumbnails;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, thumbnails.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'ThumbnailTrack',
    )..add('thumbnails', thumbnails)).toString();
  }
}

class ThumbnailTrackBuilder
    implements Builder<ThumbnailTrack, ThumbnailTrackBuilder> {
  _$ThumbnailTrack? _$v;

  List<Thumbnail>? _thumbnails;
  List<Thumbnail>? get thumbnails => _$this._thumbnails;
  set thumbnails(List<Thumbnail>? thumbnails) =>
      _$this._thumbnails = thumbnails;

  ThumbnailTrackBuilder() {
    ThumbnailTrack._initialize(this);
  }

  ThumbnailTrackBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _thumbnails = $v.thumbnails;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ThumbnailTrack other) {
    _$v = other as _$ThumbnailTrack;
  }

  @override
  void update(void Function(ThumbnailTrackBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ThumbnailTrack build() => _build();

  _$ThumbnailTrack _build() {
    final _$result =
        _$v ??
        _$ThumbnailTrack._(
          thumbnails: BuiltValueNullFieldError.checkNotNull(
            thumbnails,
            r'ThumbnailTrack',
            'thumbnails',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
