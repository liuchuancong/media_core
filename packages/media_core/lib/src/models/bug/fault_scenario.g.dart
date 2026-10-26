// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fault_scenario.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$FaultScenario extends FaultScenario {
  @override
  final String id;
  @override
  final String name;
  @override
  final List<FaultConfig> faults;
  @override
  final bool enabled;
  @override
  final bool repeat;
  @override
  final int? maxRuns;
  @override
  final String? description;
  @override
  final Map<String, Object?> metadata;

  factory _$FaultScenario([void Function(FaultScenarioBuilder)? updates]) =>
      (FaultScenarioBuilder()..update(updates))._build();

  _$FaultScenario._({
    required this.id,
    required this.name,
    required this.faults,
    required this.enabled,
    required this.repeat,
    this.maxRuns,
    this.description,
    required this.metadata,
  }) : super._();
  @override
  FaultScenario rebuild(void Function(FaultScenarioBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  FaultScenarioBuilder toBuilder() => FaultScenarioBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is FaultScenario &&
        id == other.id &&
        name == other.name &&
        faults == other.faults &&
        enabled == other.enabled &&
        repeat == other.repeat &&
        maxRuns == other.maxRuns &&
        description == other.description &&
        metadata == other.metadata;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, faults.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, repeat.hashCode);
    _$hash = $jc(_$hash, maxRuns.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, metadata.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'FaultScenario')
          ..add('id', id)
          ..add('name', name)
          ..add('faults', faults)
          ..add('enabled', enabled)
          ..add('repeat', repeat)
          ..add('maxRuns', maxRuns)
          ..add('description', description)
          ..add('metadata', metadata))
        .toString();
  }
}

class FaultScenarioBuilder
    implements Builder<FaultScenario, FaultScenarioBuilder> {
  _$FaultScenario? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  List<FaultConfig>? _faults;
  List<FaultConfig>? get faults => _$this._faults;
  set faults(List<FaultConfig>? faults) => _$this._faults = faults;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  bool? _repeat;
  bool? get repeat => _$this._repeat;
  set repeat(bool? repeat) => _$this._repeat = repeat;

  int? _maxRuns;
  int? get maxRuns => _$this._maxRuns;
  set maxRuns(int? maxRuns) => _$this._maxRuns = maxRuns;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  Map<String, Object?>? _metadata;
  Map<String, Object?>? get metadata => _$this._metadata;
  set metadata(Map<String, Object?>? metadata) => _$this._metadata = metadata;

  FaultScenarioBuilder() {
    FaultScenario._initialize(this);
  }

  FaultScenarioBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _faults = $v.faults;
      _enabled = $v.enabled;
      _repeat = $v.repeat;
      _maxRuns = $v.maxRuns;
      _description = $v.description;
      _metadata = $v.metadata;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(FaultScenario other) {
    _$v = other as _$FaultScenario;
  }

  @override
  void update(void Function(FaultScenarioBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  FaultScenario build() => _build();

  _$FaultScenario _build() {
    FaultScenario._normalize(this);
    final _$result =
        _$v ??
        _$FaultScenario._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'FaultScenario', 'id'),
          name: BuiltValueNullFieldError.checkNotNull(
            name,
            r'FaultScenario',
            'name',
          ),
          faults: BuiltValueNullFieldError.checkNotNull(
            faults,
            r'FaultScenario',
            'faults',
          ),
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'FaultScenario',
            'enabled',
          ),
          repeat: BuiltValueNullFieldError.checkNotNull(
            repeat,
            r'FaultScenario',
            'repeat',
          ),
          maxRuns: maxRuns,
          description: description,
          metadata: BuiltValueNullFieldError.checkNotNull(
            metadata,
            r'FaultScenario',
            'metadata',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
