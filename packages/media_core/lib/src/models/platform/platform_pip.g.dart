// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_pip.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlatformPip extends PlatformPip {
  @override
  final bool enabled;
  @override
  final bool systemPip;
  @override
  final bool customFloatingWindow;
  @override
  final bool autoEnter;
  @override
  final bool backgroundAudio;
  @override
  final bool resizeable;
  @override
  final bool keepControls;

  factory _$PlatformPip([void Function(PlatformPipBuilder)? updates]) =>
      (PlatformPipBuilder()..update(updates))._build();

  _$PlatformPip._({
    required this.enabled,
    required this.systemPip,
    required this.customFloatingWindow,
    required this.autoEnter,
    required this.backgroundAudio,
    required this.resizeable,
    required this.keepControls,
  }) : super._();
  @override
  PlatformPip rebuild(void Function(PlatformPipBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlatformPipBuilder toBuilder() => PlatformPipBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlatformPip &&
        enabled == other.enabled &&
        systemPip == other.systemPip &&
        customFloatingWindow == other.customFloatingWindow &&
        autoEnter == other.autoEnter &&
        backgroundAudio == other.backgroundAudio &&
        resizeable == other.resizeable &&
        keepControls == other.keepControls;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, systemPip.hashCode);
    _$hash = $jc(_$hash, customFloatingWindow.hashCode);
    _$hash = $jc(_$hash, autoEnter.hashCode);
    _$hash = $jc(_$hash, backgroundAudio.hashCode);
    _$hash = $jc(_$hash, resizeable.hashCode);
    _$hash = $jc(_$hash, keepControls.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlatformPip')
          ..add('enabled', enabled)
          ..add('systemPip', systemPip)
          ..add('customFloatingWindow', customFloatingWindow)
          ..add('autoEnter', autoEnter)
          ..add('backgroundAudio', backgroundAudio)
          ..add('resizeable', resizeable)
          ..add('keepControls', keepControls))
        .toString();
  }
}

class PlatformPipBuilder implements Builder<PlatformPip, PlatformPipBuilder> {
  _$PlatformPip? _$v;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  bool? _systemPip;
  bool? get systemPip => _$this._systemPip;
  set systemPip(bool? systemPip) => _$this._systemPip = systemPip;

  bool? _customFloatingWindow;
  bool? get customFloatingWindow => _$this._customFloatingWindow;
  set customFloatingWindow(bool? customFloatingWindow) =>
      _$this._customFloatingWindow = customFloatingWindow;

  bool? _autoEnter;
  bool? get autoEnter => _$this._autoEnter;
  set autoEnter(bool? autoEnter) => _$this._autoEnter = autoEnter;

  bool? _backgroundAudio;
  bool? get backgroundAudio => _$this._backgroundAudio;
  set backgroundAudio(bool? backgroundAudio) =>
      _$this._backgroundAudio = backgroundAudio;

  bool? _resizeable;
  bool? get resizeable => _$this._resizeable;
  set resizeable(bool? resizeable) => _$this._resizeable = resizeable;

  bool? _keepControls;
  bool? get keepControls => _$this._keepControls;
  set keepControls(bool? keepControls) => _$this._keepControls = keepControls;

  PlatformPipBuilder() {
    PlatformPip._initialize(this);
  }

  PlatformPipBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _enabled = $v.enabled;
      _systemPip = $v.systemPip;
      _customFloatingWindow = $v.customFloatingWindow;
      _autoEnter = $v.autoEnter;
      _backgroundAudio = $v.backgroundAudio;
      _resizeable = $v.resizeable;
      _keepControls = $v.keepControls;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlatformPip other) {
    _$v = other as _$PlatformPip;
  }

  @override
  void update(void Function(PlatformPipBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlatformPip build() => _build();

  _$PlatformPip _build() {
    final _$result =
        _$v ??
        _$PlatformPip._(
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'PlatformPip',
            'enabled',
          ),
          systemPip: BuiltValueNullFieldError.checkNotNull(
            systemPip,
            r'PlatformPip',
            'systemPip',
          ),
          customFloatingWindow: BuiltValueNullFieldError.checkNotNull(
            customFloatingWindow,
            r'PlatformPip',
            'customFloatingWindow',
          ),
          autoEnter: BuiltValueNullFieldError.checkNotNull(
            autoEnter,
            r'PlatformPip',
            'autoEnter',
          ),
          backgroundAudio: BuiltValueNullFieldError.checkNotNull(
            backgroundAudio,
            r'PlatformPip',
            'backgroundAudio',
          ),
          resizeable: BuiltValueNullFieldError.checkNotNull(
            resizeable,
            r'PlatformPip',
            'resizeable',
          ),
          keepControls: BuiltValueNullFieldError.checkNotNull(
            keepControls,
            r'PlatformPip',
            'keepControls',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
