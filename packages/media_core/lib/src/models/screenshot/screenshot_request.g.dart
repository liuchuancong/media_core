// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screenshot_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ScreenshotRequest extends ScreenshotRequest {
  @override
  final ScreenshotFormat format;
  @override
  final int quality;
  @override
  final bool includeSubtitles;

  factory _$ScreenshotRequest([
    void Function(ScreenshotRequestBuilder)? updates,
  ]) => (ScreenshotRequestBuilder()..update(updates))._build();

  _$ScreenshotRequest._({
    required this.format,
    required this.quality,
    required this.includeSubtitles,
  }) : super._();
  @override
  ScreenshotRequest rebuild(void Function(ScreenshotRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ScreenshotRequestBuilder toBuilder() =>
      ScreenshotRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ScreenshotRequest &&
        format == other.format &&
        quality == other.quality &&
        includeSubtitles == other.includeSubtitles;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, format.hashCode);
    _$hash = $jc(_$hash, quality.hashCode);
    _$hash = $jc(_$hash, includeSubtitles.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ScreenshotRequest')
          ..add('format', format)
          ..add('quality', quality)
          ..add('includeSubtitles', includeSubtitles))
        .toString();
  }
}

class ScreenshotRequestBuilder
    implements Builder<ScreenshotRequest, ScreenshotRequestBuilder> {
  _$ScreenshotRequest? _$v;

  ScreenshotFormat? _format;
  ScreenshotFormat? get format => _$this._format;
  set format(ScreenshotFormat? format) => _$this._format = format;

  int? _quality;
  int? get quality => _$this._quality;
  set quality(int? quality) => _$this._quality = quality;

  bool? _includeSubtitles;
  bool? get includeSubtitles => _$this._includeSubtitles;
  set includeSubtitles(bool? includeSubtitles) =>
      _$this._includeSubtitles = includeSubtitles;

  ScreenshotRequestBuilder() {
    ScreenshotRequest._initialize(this);
  }

  ScreenshotRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _format = $v.format;
      _quality = $v.quality;
      _includeSubtitles = $v.includeSubtitles;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ScreenshotRequest other) {
    _$v = other as _$ScreenshotRequest;
  }

  @override
  void update(void Function(ScreenshotRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ScreenshotRequest build() => _build();

  _$ScreenshotRequest _build() {
    final _$result =
        _$v ??
        _$ScreenshotRequest._(
          format: BuiltValueNullFieldError.checkNotNull(
            format,
            r'ScreenshotRequest',
            'format',
          ),
          quality: BuiltValueNullFieldError.checkNotNull(
            quality,
            r'ScreenshotRequest',
            'quality',
          ),
          includeSubtitles: BuiltValueNullFieldError.checkNotNull(
            includeSubtitles,
            r'ScreenshotRequest',
            'includeSubtitles',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
