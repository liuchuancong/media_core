// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_renderer.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlatformRenderer extends PlatformRenderer {
  @override
  final PlatformRendererType type;
  @override
  final bool hardwareAcceleration;
  @override
  final bool gpuRendering;
  @override
  final bool supportsSurface;
  @override
  final bool supportsTexture;
  @override
  final bool supportsOverlay;

  factory _$PlatformRenderer([
    void Function(PlatformRendererBuilder)? updates,
  ]) => (PlatformRendererBuilder()..update(updates))._build();

  _$PlatformRenderer._({
    required this.type,
    required this.hardwareAcceleration,
    required this.gpuRendering,
    required this.supportsSurface,
    required this.supportsTexture,
    required this.supportsOverlay,
  }) : super._();
  @override
  PlatformRenderer rebuild(void Function(PlatformRendererBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlatformRendererBuilder toBuilder() =>
      PlatformRendererBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlatformRenderer &&
        type == other.type &&
        hardwareAcceleration == other.hardwareAcceleration &&
        gpuRendering == other.gpuRendering &&
        supportsSurface == other.supportsSurface &&
        supportsTexture == other.supportsTexture &&
        supportsOverlay == other.supportsOverlay;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, hardwareAcceleration.hashCode);
    _$hash = $jc(_$hash, gpuRendering.hashCode);
    _$hash = $jc(_$hash, supportsSurface.hashCode);
    _$hash = $jc(_$hash, supportsTexture.hashCode);
    _$hash = $jc(_$hash, supportsOverlay.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlatformRenderer')
          ..add('type', type)
          ..add('hardwareAcceleration', hardwareAcceleration)
          ..add('gpuRendering', gpuRendering)
          ..add('supportsSurface', supportsSurface)
          ..add('supportsTexture', supportsTexture)
          ..add('supportsOverlay', supportsOverlay))
        .toString();
  }
}

class PlatformRendererBuilder
    implements Builder<PlatformRenderer, PlatformRendererBuilder> {
  _$PlatformRenderer? _$v;

  PlatformRendererType? _type;
  PlatformRendererType? get type => _$this._type;
  set type(PlatformRendererType? type) => _$this._type = type;

  bool? _hardwareAcceleration;
  bool? get hardwareAcceleration => _$this._hardwareAcceleration;
  set hardwareAcceleration(bool? hardwareAcceleration) =>
      _$this._hardwareAcceleration = hardwareAcceleration;

  bool? _gpuRendering;
  bool? get gpuRendering => _$this._gpuRendering;
  set gpuRendering(bool? gpuRendering) => _$this._gpuRendering = gpuRendering;

  bool? _supportsSurface;
  bool? get supportsSurface => _$this._supportsSurface;
  set supportsSurface(bool? supportsSurface) =>
      _$this._supportsSurface = supportsSurface;

  bool? _supportsTexture;
  bool? get supportsTexture => _$this._supportsTexture;
  set supportsTexture(bool? supportsTexture) =>
      _$this._supportsTexture = supportsTexture;

  bool? _supportsOverlay;
  bool? get supportsOverlay => _$this._supportsOverlay;
  set supportsOverlay(bool? supportsOverlay) =>
      _$this._supportsOverlay = supportsOverlay;

  PlatformRendererBuilder() {
    PlatformRenderer._initialize(this);
  }

  PlatformRendererBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _hardwareAcceleration = $v.hardwareAcceleration;
      _gpuRendering = $v.gpuRendering;
      _supportsSurface = $v.supportsSurface;
      _supportsTexture = $v.supportsTexture;
      _supportsOverlay = $v.supportsOverlay;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlatformRenderer other) {
    _$v = other as _$PlatformRenderer;
  }

  @override
  void update(void Function(PlatformRendererBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlatformRenderer build() => _build();

  _$PlatformRenderer _build() {
    final _$result =
        _$v ??
        _$PlatformRenderer._(
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'PlatformRenderer',
            'type',
          ),
          hardwareAcceleration: BuiltValueNullFieldError.checkNotNull(
            hardwareAcceleration,
            r'PlatformRenderer',
            'hardwareAcceleration',
          ),
          gpuRendering: BuiltValueNullFieldError.checkNotNull(
            gpuRendering,
            r'PlatformRenderer',
            'gpuRendering',
          ),
          supportsSurface: BuiltValueNullFieldError.checkNotNull(
            supportsSurface,
            r'PlatformRenderer',
            'supportsSurface',
          ),
          supportsTexture: BuiltValueNullFieldError.checkNotNull(
            supportsTexture,
            r'PlatformRenderer',
            'supportsTexture',
          ),
          supportsOverlay: BuiltValueNullFieldError.checkNotNull(
            supportsOverlay,
            r'PlatformRenderer',
            'supportsOverlay',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
