// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fault_config.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$FaultConfig extends FaultConfig {
  @override
  final FaultType type;
  @override
  final bool enabled;
  @override
  final double probability;
  @override
  final Duration? delay;
  @override
  final Duration? duration;
  @override
  final int? maxOccurrences;
  @override
  final String? message;
  @override
  final Map<String, Object?> metadata;

  factory _$FaultConfig([void Function(FaultConfigBuilder)? updates]) =>
      (FaultConfigBuilder()..update(updates))._build();

  _$FaultConfig._({
    required this.type,
    required this.enabled,
    required this.probability,
    this.delay,
    this.duration,
    this.maxOccurrences,
    this.message,
    required this.metadata,
  }) : super._();
  @override
  FaultConfig rebuild(void Function(FaultConfigBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  FaultConfigBuilder toBuilder() => FaultConfigBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is FaultConfig &&
        type == other.type &&
        enabled == other.enabled &&
        probability == other.probability &&
        delay == other.delay &&
        duration == other.duration &&
        maxOccurrences == other.maxOccurrences &&
        message == other.message &&
        metadata == other.metadata;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, probability.hashCode);
    _$hash = $jc(_$hash, delay.hashCode);
    _$hash = $jc(_$hash, duration.hashCode);
    _$hash = $jc(_$hash, maxOccurrences.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, metadata.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'FaultConfig')
          ..add('type', type)
          ..add('enabled', enabled)
          ..add('probability', probability)
          ..add('delay', delay)
          ..add('duration', duration)
          ..add('maxOccurrences', maxOccurrences)
          ..add('message', message)
          ..add('metadata', metadata))
        .toString();
  }
}

class FaultConfigBuilder implements Builder<FaultConfig, FaultConfigBuilder> {
  _$FaultConfig? _$v;

  FaultType? _type;
  FaultType? get type => _$this._type;
  set type(FaultType? type) => _$this._type = type;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  double? _probability;
  double? get probability => _$this._probability;
  set probability(double? probability) => _$this._probability = probability;

  Duration? _delay;
  Duration? get delay => _$this._delay;
  set delay(Duration? delay) => _$this._delay = delay;

  Duration? _duration;
  Duration? get duration => _$this._duration;
  set duration(Duration? duration) => _$this._duration = duration;

  int? _maxOccurrences;
  int? get maxOccurrences => _$this._maxOccurrences;
  set maxOccurrences(int? maxOccurrences) =>
      _$this._maxOccurrences = maxOccurrences;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  Map<String, Object?>? _metadata;
  Map<String, Object?>? get metadata => _$this._metadata;
  set metadata(Map<String, Object?>? metadata) => _$this._metadata = metadata;

  FaultConfigBuilder() {
    FaultConfig._initialize(this);
  }

  FaultConfigBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _enabled = $v.enabled;
      _probability = $v.probability;
      _delay = $v.delay;
      _duration = $v.duration;
      _maxOccurrences = $v.maxOccurrences;
      _message = $v.message;
      _metadata = $v.metadata;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(FaultConfig other) {
    _$v = other as _$FaultConfig;
  }

  @override
  void update(void Function(FaultConfigBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  FaultConfig build() => _build();

  _$FaultConfig _build() {
    FaultConfig._validate(this);
    final _$result =
        _$v ??
        _$FaultConfig._(
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'FaultConfig',
            'type',
          ),
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'FaultConfig',
            'enabled',
          ),
          probability: BuiltValueNullFieldError.checkNotNull(
            probability,
            r'FaultConfig',
            'probability',
          ),
          delay: delay,
          duration: duration,
          maxOccurrences: maxOccurrences,
          message: message,
          metadata: BuiltValueNullFieldError.checkNotNull(
            metadata,
            r'FaultConfig',
            'metadata',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
