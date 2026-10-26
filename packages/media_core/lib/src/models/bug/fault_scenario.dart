import 'package:built_value/built_value.dart';
import 'package:media_core/src/bug/fault_type.dart' show FaultType;
import 'package:media_core/src/models/bug/fault_config.dart' show FaultConfig;

part 'fault_scenario.g.dart';

/// Defines a collection of fault configurations that can be executed
/// as a single fault injection scenario.
///
/// A scenario only describes faults and their execution policy.
/// It does not execute or schedule faults.
///
/// ```text
/// FaultScenario
///      │
///      ├── FaultConfig
///      │      └── FaultType
///      │
///      └── FaultScheduler
/// ```
abstract class FaultScenario implements Built<FaultScenario, FaultScenarioBuilder> {
  /// Builds FaultScenario from a [updates] callback — the codegen entry.
  factory FaultScenario([void Function(FaultScenarioBuilder)? updates]) = _$FaultScenario;

  /// Groups [faults] behind one identifiable, repeatable scenario.
  factory FaultScenario.of({
    required String id,
    required String name,
    List<FaultConfig> faults = const <FaultConfig>[],
    bool enabled = true,
    bool repeat = false,
    int? maxRuns,
    String? description,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return FaultScenario(
      (builder) => builder
        ..id = id
        ..name = name
        ..faults = faults
        ..enabled = enabled
        ..repeat = repeat
        ..maxRuns = maxRuns
        ..description = description
        ..metadata = metadata,
    );
  }

  FaultScenario._();

  /// A scenario is on, runs once, and holds empty collections unless the
  /// caller says otherwise.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(FaultScenarioBuilder builder) => builder
    ..faults = const <FaultConfig>[]
    ..enabled = true
    ..repeat = false
    ..metadata = const <String, Object?>{};

  /// The identifying text is trimmed to what it means, the faults and
  /// metadata are frozen so a later edit elsewhere cannot rename a
  /// scheduled scenario mid-run, and a run limit that is not a limit is
  /// refused.
  @BuiltValueHook(finalizeBuilder: true)
  static void _normalize(FaultScenarioBuilder builder) {
    final id = builder.id;
    if (id != null) {
      builder.id = _requireText(id, 'id');
    }
    final name = builder.name;
    if (name != null) {
      builder.name = _requireText(name, 'name');
    }
    final faults = builder.faults;
    if (faults != null) {
      builder.faults = List<FaultConfig>.unmodifiable(faults);
    }
    final metadata = builder.metadata;
    if (metadata != null) {
      builder.metadata = Map<String, Object?>.unmodifiable(metadata);
    }
    final maxRuns = builder.maxRuns;
    if (maxRuns != null && maxRuns <= 0) {
      throw ArgumentError.value(maxRuns, 'maxRuns', 'maxRuns must be greater than 0.');
    }
  }

  /// Unique scenario identifier.
  String get id;

  /// Human-readable scenario name.
  String get name;

  /// Fault configurations contained in this scenario.
  List<FaultConfig> get faults;

  /// Whether the scenario is enabled.
  bool get enabled;

  /// Whether the scenario should repeat.
  bool get repeat;

  /// Maximum number of scenario runs.
  ///
  /// `null` means unlimited runs when [repeat] is enabled.
  int? get maxRuns;

  /// Optional scenario description.
  String? get description;

  /// Additional scenario metadata.
  Map<String, Object?> get metadata;

  /// Whether the scenario is currently active.
  bool get isActive => enabled && faults.isNotEmpty;

  /// Whether the scenario is disabled.
  bool get isDisabled => !enabled;

  /// Whether the scenario contains no faults.
  bool get isEmpty => faults.isEmpty;

  /// Whether the scenario contains at least one fault.
  bool get isNotEmpty => faults.isNotEmpty;

  /// Number of configured faults.
  int get faultCount => faults.length;

  /// Whether a description is available.
  bool get hasDescription => description != null && description!.trim().isNotEmpty;

  /// Whether metadata is available.
  bool get hasMetadata => metadata.isNotEmpty;

  /// Whether the scenario has a run limit.
  bool get hasRunLimit => maxRuns != null;

  /// Whether the scenario can repeat.
  bool get canRepeat => repeat && enabled;

  /// Whether this scenario runs only once.
  bool get isSingleRun => !repeat;

  /// Whether any contained fault is disabled.
  bool get containsDisabledFault => faults.any((fault) => fault.isDisabled);

  /// Whether the scenario contains a random fault.
  bool get containsRandomFault => faults.any((fault) => fault.type.isRandom);

  /// Whether the scenario contains a deterministic fault.
  bool get containsDeterministicFault => faults.any((fault) => fault.type.isDeterministic);

  /// Whether the scenario contains a disruptive fault.
  bool get containsDisruptiveFault => faults.any((fault) => fault.type.isDisruptive);

  /// Whether the scenario contains a stress fault.
  bool get containsStressFault => faults.any((fault) => fault.type.isStress);

  /// Whether the scenario contains a chaos fault.
  bool get containsChaosFault => faults.any((fault) => fault.type.isChaos);

  /// Finds the first fault with the given type.
  FaultConfig? findByType(FaultType type) {
    for (final fault in faults) {
      if (fault.type == type) {
        return fault;
      }
    }

    return null;
  }

  /// Whether the scenario contains the given fault type.
  bool containsType(FaultType type) {
    return findByType(type) != null;
  }

  /// Returns an immutable metadata view.
  Map<String, Object?> get metadataView => Map<String, Object?>.unmodifiable(metadata);

  /// Whether a metadata key exists.
  bool containsMetadata(String key) {
    return metadata.containsKey(key.trim());
  }

  /// Returns a metadata value.
  Object? metadataValue(String key) {
    return metadata[key.trim()];
  }

  /// Returns a typed metadata value.
  T? metadataAs<T>(String key) {
    final value = metadataValue(key);

    if (value is T) {
      return value;
    }

    return null;
  }

  /// Enables the scenario.
  FaultScenario enable() {
    if (enabled) {
      return this;
    }

    return rebuild((builder) => builder..enabled = true);
  }

  /// Disables the scenario.
  FaultScenario disable() {
    if (!enabled) {
      return this;
    }

    return rebuild((builder) => builder..enabled = false);
  }

  /// Adds a fault to the scenario.
  FaultScenario withFault(FaultConfig fault) {
    return rebuild((builder) => builder..faults = <FaultConfig>[...faults, fault]);
  }

  /// Adds multiple faults to the scenario.
  FaultScenario withFaults(Iterable<FaultConfig> values) {
    final additions = values.toList(growable: false);

    if (additions.isEmpty) {
      return this;
    }

    return rebuild((builder) => builder..faults = <FaultConfig>[...faults, ...additions]);
  }

  /// Replaces all faults in the scenario.
  FaultScenario replaceFaults(Iterable<FaultConfig> values) {
    return rebuild((builder) => builder..faults = values.toList(growable: false));
  }

  /// Removes a fault by index.
  FaultScenario removeFaultAt(int index) {
    if (index < 0 || index >= faults.length) {
      throw RangeError.index(index, faults, 'index');
    }

    final nextFaults = <FaultConfig>[...faults]..removeAt(index);

    return rebuild((builder) => builder..faults = nextFaults);
  }

  /// Removes the first matching fault.
  FaultScenario removeFault(FaultConfig fault) {
    final index = faults.indexOf(fault);

    if (index < 0) {
      return this;
    }

    return removeFaultAt(index);
  }

  /// Removes all faults.
  FaultScenario clearFaults() {
    if (faults.isEmpty) {
      return this;
    }

    return rebuild((builder) => builder..faults = const <FaultConfig>[]);
  }

  /// Sets the maximum number of runs.
  ///
  /// Passing `null` removes the limit.
  FaultScenario withMaxRuns(int? value) {
    if (value != null && value <= 0) {
      throw ArgumentError.value(value, 'value', 'maxRuns must be greater than 0.');
    }

    return rebuild((builder) => builder..maxRuns = value);
  }

  /// Removes the maximum run limit.
  FaultScenario withoutMaxRuns() {
    return withMaxRuns(null);
  }

  /// Enables single-run execution.
  FaultScenario asSingleRun() {
    return rebuild((builder) => builder..repeat = false);
  }

  /// Enables repeating execution.
  FaultScenario asRepeating() {
    return rebuild((builder) => builder..repeat = true);
  }

  /// Changes the description.
  ///
  /// Passing `null` clears the description.
  FaultScenario withDescription(String? value) {
    final normalized = value?.trim();

    return rebuild((builder) => builder..description = normalized);
  }

  /// Removes the description.
  FaultScenario withoutDescription() {
    return withDescription(null);
  }

  /// Adds or replaces a metadata entry.
  FaultScenario withMetadata(String key, Object? value) {
    final normalizedKey = key.trim();

    if (normalizedKey.isEmpty) {
      throw ArgumentError.value(key, 'key', 'Metadata key must not be empty.');
    }

    final nextMetadata = <String, Object?>{...metadata, normalizedKey: value};

    return rebuild((builder) => builder..metadata = nextMetadata);
  }

  /// Adds multiple metadata entries.
  FaultScenario withMetadataMap(Map<String, Object?> values) {
    if (values.isEmpty) {
      return this;
    }

    final nextMetadata = <String, Object?>{...metadata};

    for (final entry in values.entries) {
      final key = entry.key.trim();

      if (key.isEmpty) {
        throw ArgumentError.value(entry.key, 'values', 'Metadata keys must not be empty.');
      }

      nextMetadata[key] = entry.value;
    }

    return rebuild((builder) => builder..metadata = nextMetadata);
  }

  /// Removes a metadata entry.
  FaultScenario withoutMetadata(String key) {
    final normalizedKey = key.trim();

    if (!metadata.containsKey(normalizedKey)) {
      return this;
    }

    final nextMetadata = <String, Object?>{...metadata}..remove(normalizedKey);

    return rebuild((builder) => builder..metadata = nextMetadata);
  }

  /// Clears all metadata.
  FaultScenario clearMetadata() {
    if (metadata.isEmpty) {
      return this;
    }

    return rebuild((builder) => builder..metadata = const <String, Object?>{});
  }

  /// Validates this scenario.
  List<String> validate() {
    final errors = <String>[];

    if (id.trim().isEmpty) {
      errors.add('id must not be empty.');
    }

    if (name.trim().isEmpty) {
      errors.add('name must not be empty.');
    }

    if (maxRuns != null && maxRuns! <= 0) {
      errors.add('maxRuns must be greater than 0.');
    }

    for (var index = 0; index < faults.length; index++) {
      final faultErrors = faults[index].validate();

      for (final error in faultErrors) {
        errors.add('fault[$index]: $error');
      }
    }

    if (repeat && maxRuns == 0) {
      errors.add('A repeating scenario cannot have maxRuns equal to 0.');
    }

    return List<String>.unmodifiable(errors);
  }

  /// Validates the scenario and throws if invalid.
  void validateOrThrow() {
    final errors = validate();

    if (errors.isEmpty) {
      return;
    }

    throw StateError('Invalid FaultScenario: ${errors.join(' ')}');
  }

  static String _requireText(String value, String name) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, name, '$name must not be empty.');
    }

    return normalized;
  }
}
