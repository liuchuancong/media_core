// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostics_config.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DiagnosticsConfig extends DiagnosticsConfig {
  @override
  final bool enabled;
  @override
  final bool loggingEnabled;
  @override
  final bool performanceMonitoringEnabled;
  @override
  final bool memoryMonitoringEnabled;
  @override
  final bool networkMonitoringEnabled;
  @override
  final LogLevel minimumLogLevel;
  @override
  final int maxPerformanceSamples;
  @override
  final Duration monitoringInterval;

  factory _$DiagnosticsConfig([
    void Function(DiagnosticsConfigBuilder)? updates,
  ]) => (DiagnosticsConfigBuilder()..update(updates))._build();

  _$DiagnosticsConfig._({
    required this.enabled,
    required this.loggingEnabled,
    required this.performanceMonitoringEnabled,
    required this.memoryMonitoringEnabled,
    required this.networkMonitoringEnabled,
    required this.minimumLogLevel,
    required this.maxPerformanceSamples,
    required this.monitoringInterval,
  }) : super._();
  @override
  DiagnosticsConfig rebuild(void Function(DiagnosticsConfigBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DiagnosticsConfigBuilder toBuilder() =>
      DiagnosticsConfigBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DiagnosticsConfig &&
        enabled == other.enabled &&
        loggingEnabled == other.loggingEnabled &&
        performanceMonitoringEnabled == other.performanceMonitoringEnabled &&
        memoryMonitoringEnabled == other.memoryMonitoringEnabled &&
        networkMonitoringEnabled == other.networkMonitoringEnabled &&
        minimumLogLevel == other.minimumLogLevel &&
        maxPerformanceSamples == other.maxPerformanceSamples &&
        monitoringInterval == other.monitoringInterval;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, loggingEnabled.hashCode);
    _$hash = $jc(_$hash, performanceMonitoringEnabled.hashCode);
    _$hash = $jc(_$hash, memoryMonitoringEnabled.hashCode);
    _$hash = $jc(_$hash, networkMonitoringEnabled.hashCode);
    _$hash = $jc(_$hash, minimumLogLevel.hashCode);
    _$hash = $jc(_$hash, maxPerformanceSamples.hashCode);
    _$hash = $jc(_$hash, monitoringInterval.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DiagnosticsConfig')
          ..add('enabled', enabled)
          ..add('loggingEnabled', loggingEnabled)
          ..add('performanceMonitoringEnabled', performanceMonitoringEnabled)
          ..add('memoryMonitoringEnabled', memoryMonitoringEnabled)
          ..add('networkMonitoringEnabled', networkMonitoringEnabled)
          ..add('minimumLogLevel', minimumLogLevel)
          ..add('maxPerformanceSamples', maxPerformanceSamples)
          ..add('monitoringInterval', monitoringInterval))
        .toString();
  }
}

class DiagnosticsConfigBuilder
    implements Builder<DiagnosticsConfig, DiagnosticsConfigBuilder> {
  _$DiagnosticsConfig? _$v;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  bool? _loggingEnabled;
  bool? get loggingEnabled => _$this._loggingEnabled;
  set loggingEnabled(bool? loggingEnabled) =>
      _$this._loggingEnabled = loggingEnabled;

  bool? _performanceMonitoringEnabled;
  bool? get performanceMonitoringEnabled =>
      _$this._performanceMonitoringEnabled;
  set performanceMonitoringEnabled(bool? performanceMonitoringEnabled) =>
      _$this._performanceMonitoringEnabled = performanceMonitoringEnabled;

  bool? _memoryMonitoringEnabled;
  bool? get memoryMonitoringEnabled => _$this._memoryMonitoringEnabled;
  set memoryMonitoringEnabled(bool? memoryMonitoringEnabled) =>
      _$this._memoryMonitoringEnabled = memoryMonitoringEnabled;

  bool? _networkMonitoringEnabled;
  bool? get networkMonitoringEnabled => _$this._networkMonitoringEnabled;
  set networkMonitoringEnabled(bool? networkMonitoringEnabled) =>
      _$this._networkMonitoringEnabled = networkMonitoringEnabled;

  LogLevel? _minimumLogLevel;
  LogLevel? get minimumLogLevel => _$this._minimumLogLevel;
  set minimumLogLevel(LogLevel? minimumLogLevel) =>
      _$this._minimumLogLevel = minimumLogLevel;

  int? _maxPerformanceSamples;
  int? get maxPerformanceSamples => _$this._maxPerformanceSamples;
  set maxPerformanceSamples(int? maxPerformanceSamples) =>
      _$this._maxPerformanceSamples = maxPerformanceSamples;

  Duration? _monitoringInterval;
  Duration? get monitoringInterval => _$this._monitoringInterval;
  set monitoringInterval(Duration? monitoringInterval) =>
      _$this._monitoringInterval = monitoringInterval;

  DiagnosticsConfigBuilder() {
    DiagnosticsConfig._initialize(this);
  }

  DiagnosticsConfigBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _enabled = $v.enabled;
      _loggingEnabled = $v.loggingEnabled;
      _performanceMonitoringEnabled = $v.performanceMonitoringEnabled;
      _memoryMonitoringEnabled = $v.memoryMonitoringEnabled;
      _networkMonitoringEnabled = $v.networkMonitoringEnabled;
      _minimumLogLevel = $v.minimumLogLevel;
      _maxPerformanceSamples = $v.maxPerformanceSamples;
      _monitoringInterval = $v.monitoringInterval;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DiagnosticsConfig other) {
    _$v = other as _$DiagnosticsConfig;
  }

  @override
  void update(void Function(DiagnosticsConfigBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DiagnosticsConfig build() => _build();

  _$DiagnosticsConfig _build() {
    DiagnosticsConfig._validate(this);
    final _$result =
        _$v ??
        _$DiagnosticsConfig._(
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'DiagnosticsConfig',
            'enabled',
          ),
          loggingEnabled: BuiltValueNullFieldError.checkNotNull(
            loggingEnabled,
            r'DiagnosticsConfig',
            'loggingEnabled',
          ),
          performanceMonitoringEnabled: BuiltValueNullFieldError.checkNotNull(
            performanceMonitoringEnabled,
            r'DiagnosticsConfig',
            'performanceMonitoringEnabled',
          ),
          memoryMonitoringEnabled: BuiltValueNullFieldError.checkNotNull(
            memoryMonitoringEnabled,
            r'DiagnosticsConfig',
            'memoryMonitoringEnabled',
          ),
          networkMonitoringEnabled: BuiltValueNullFieldError.checkNotNull(
            networkMonitoringEnabled,
            r'DiagnosticsConfig',
            'networkMonitoringEnabled',
          ),
          minimumLogLevel: BuiltValueNullFieldError.checkNotNull(
            minimumLogLevel,
            r'DiagnosticsConfig',
            'minimumLogLevel',
          ),
          maxPerformanceSamples: BuiltValueNullFieldError.checkNotNull(
            maxPerformanceSamples,
            r'DiagnosticsConfig',
            'maxPerformanceSamples',
          ),
          monitoringInterval: BuiltValueNullFieldError.checkNotNull(
            monitoringInterval,
            r'DiagnosticsConfig',
            'monitoringInterval',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
