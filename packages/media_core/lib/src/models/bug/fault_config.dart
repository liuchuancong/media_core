import 'package:built_value/built_value.dart';
import 'package:media_core/src/bug/fault_type.dart' show FaultType;

part 'fault_config.g.dart';

/// Configuration for a single fault injection.
///
/// [FaultConfig] describes how a fault should be injected.
/// It does not execute the fault and does not schedule it.
///
/// ```text
/// FaultType
///     ↓
/// FaultConfig
///     ↓
/// FaultInjector / FaultScheduler
/// ```
abstract class FaultConfig implements Built<FaultConfig, FaultConfigBuilder> {
  /// Builds FaultConfig from a [updates] callback — the codegen entry.
  factory FaultConfig([void Function(FaultConfigBuilder)? updates]) = _$FaultConfig;

  /// Describes one fault to inject, including when it fires and how often it may repeat.
  factory FaultConfig.of({
    required FaultType type,
    bool enabled = true,
    double probability = 1.0,
    Duration? delay,
    Duration? duration,
    int? maxOccurrences,
    String? message,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return FaultConfig(
      (builder) => builder
        ..type = type
        ..enabled = enabled
        ..probability = probability
        ..delay = delay
        ..duration = duration
        ..maxOccurrences = maxOccurrences
        ..message = message
        ..metadata = metadata,
    );
  }

  /// Creates a configuration for a deterministic fault.
  factory FaultConfig.deterministic({
    required FaultType type,
    bool enabled = true,
    Duration? delay,
    Duration? duration,
    int? maxOccurrences,
    String? message,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return FaultConfig.of(
      type: type,
      enabled: enabled,
      delay: delay,
      duration: duration,
      maxOccurrences: maxOccurrences,
      message: message,
      metadata: metadata,
    );
  }

  /// Creates a configuration for a probabilistic fault.
  factory FaultConfig.random({
    required FaultType type,
    bool enabled = true,
    double probability = 0.5,
    Duration? delay,
    Duration? duration,
    int? maxOccurrences,
    String? message,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return FaultConfig.of(
      type: type,
      enabled: enabled,
      probability: probability,
      delay: delay,
      duration: duration,
      maxOccurrences: maxOccurrences,
      message: message,
      metadata: metadata,
    );
  }

  FaultConfig._();

  /// A fault is on, fires for certain, and carries no extra data unless the
  /// caller says otherwise; a malformed probability or occurrence limit is
  /// refused here rather than half-injected later.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(FaultConfigBuilder builder) => builder
    ..enabled = true
    ..probability = 1.0
    ..metadata = const <String, Object?>{};

  @BuiltValueHook(finalizeBuilder: true)
  static void _validate(FaultConfigBuilder builder) {
    final probability = builder.probability;
    final maxOccurrences = builder.maxOccurrences;
    assert(
      probability == null || (probability >= 0.0 && probability <= 1.0),
      'probability must be between 0.0 and 1.0.',
    );
    assert(maxOccurrences == null || maxOccurrences > 0, 'maxOccurrences must be greater than 0.');
  }

  /// Fault type.
  FaultType get type;

  /// Whether this fault configuration is enabled.
  bool get enabled;

  /// Probability of injecting this fault.
  ///
  /// `1.0` means always.
  /// `0.0` means never.
  double get probability;

  /// Delay before fault injection.
  Duration? get delay;

  /// Optional duration for the fault.
  Duration? get duration;

  /// Maximum number of times this fault may occur.
  ///
  /// `null` means unlimited.
  int? get maxOccurrences;

  /// Optional human-readable fault message.
  String? get message;

  /// Additional fault metadata.
  Map<String, Object?> get metadata;

  /// Whether this configuration is active.
  bool get isActive => enabled && probability > 0.0;

  /// Whether this configuration is disabled.
  bool get isDisabled => !enabled;

  /// Whether the fault has a guaranteed probability.
  bool get isGuaranteed => probability >= 1.0;

  /// Whether the fault is probabilistic.
  bool get isProbabilistic => probability > 0.0 && probability < 1.0;

  /// Whether this configuration has a delay.
  bool get hasDelay => delay != null;

  /// Whether this configuration has a duration.
  bool get hasDuration => duration != null;

  /// Whether this configuration has an occurrence limit.
  bool get hasMaxOccurrences => maxOccurrences != null;

  /// Whether this configuration has a message.
  bool get hasMessage => message != null && message!.trim().isNotEmpty;

  /// Whether this configuration has metadata.
  bool get hasMetadata => metadata.isNotEmpty;

  /// Whether this configuration represents a deterministic fault.
  bool get isDeterministic => type.isDeterministic && isGuaranteed;

  /// Whether this configuration represents a random fault.
  bool get isRandom => type.isRandom;

  /// Whether this configuration represents a disruptive fault.
  bool get isDisruptive => type.isDisruptive;

  /// Whether this configuration represents a stress fault.
  bool get isStress => type.isStress;

  /// Whether this configuration represents a chaos fault.
  bool get isChaos => type.isChaos;

  /// Whether this configuration requires random-fault permission.
  bool get requiresRandomMode => isRandom || isProbabilistic;

  /// Whether this configuration requires deterministic-fault permission.
  bool get requiresDeterministicMode => !requiresRandomMode && type.isDeterministic;

  /// Whether this configuration requires disruptive-fault permission.
  bool get requiresDisruptiveMode => isDisruptive;

  /// Whether this configuration requires stress-fault permission.
  bool get requiresStressMode => isStress;

  /// Whether this configuration requires chaos-fault permission.
  bool get requiresChaosMode => isChaos;

  /// Enables this fault.
  FaultConfig enable() {
    if (enabled) {
      return this;
    }

    return rebuild((builder) => builder..enabled = true);
  }

  /// Disables this fault.
  FaultConfig disable() {
    if (!enabled) {
      return this;
    }

    return rebuild((builder) => builder..enabled = false);
  }

  /// Changes the fault type.
  FaultConfig withType(FaultType value) {
    return rebuild((builder) => builder..type = value);
  }

  /// Changes the probability.
  FaultConfig withProbability(double value) {
    _validateProbability(value);

    return rebuild((builder) => builder..probability = value);
  }

  /// Changes the delay.
  ///
  /// Passing `null` clears the delay.
  FaultConfig withDelay(Duration? value) {
    if (value != null && value.isNegative) {
      throw ArgumentError.value(value, 'value', 'delay must not be negative.');
    }

    return rebuild((builder) => builder..delay = value);
  }

  /// Removes the delay.
  FaultConfig withoutDelay() {
    return withDelay(null);
  }

  /// Changes the fault duration.
  ///
  /// Passing `null` clears the duration.
  FaultConfig withDuration(Duration? value) {
    if (value != null && value.isNegative) {
      throw ArgumentError.value(value, 'value', 'duration must not be negative.');
    }

    return rebuild((builder) => builder..duration = value);
  }

  /// Removes the fault duration.
  FaultConfig withoutDuration() {
    return withDuration(null);
  }

  /// Changes the maximum occurrence count.
  ///
  /// Passing `null` removes the occurrence limit.
  FaultConfig withMaxOccurrences(int? value) {
    if (value != null && value <= 0) {
      throw ArgumentError.value(value, 'value', 'maxOccurrences must be greater than 0.');
    }

    return rebuild((builder) => builder..maxOccurrences = value);
  }

  /// Removes the maximum occurrence limit.
  FaultConfig withoutMaxOccurrences() {
    return withMaxOccurrences(null);
  }

  /// Changes the fault message.
  ///
  /// Passing `null` clears the message.
  FaultConfig withMessage(String? value) {
    final normalized = value?.trim();

    return rebuild((builder) => builder..message = normalized);
  }

  /// Removes the fault message.
  FaultConfig withoutMessage() {
    return withMessage(null);
  }

  /// Adds or replaces a metadata entry.
  FaultConfig withMetadata(String key, Object? value) {
    final normalizedKey = key.trim();

    if (normalizedKey.isEmpty) {
      throw ArgumentError.value(key, 'key', 'Metadata key must not be empty.');
    }

    final nextMetadata = <String, Object?>{...metadata, normalizedKey: value};

    return rebuild((builder) => builder..metadata = nextMetadata);
  }

  /// Adds multiple metadata entries.
  FaultConfig withMetadataMap(Map<String, Object?> values) {
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
  FaultConfig withoutMetadata(String key) {
    final normalizedKey = key.trim();

    if (!metadata.containsKey(normalizedKey)) {
      return this;
    }

    final nextMetadata = <String, Object?>{...metadata}..remove(normalizedKey);

    return rebuild((builder) => builder..metadata = nextMetadata);
  }

  /// Clears all metadata.
  FaultConfig clearMetadata() {
    if (metadata.isEmpty) {
      return this;
    }

    return rebuild((builder) => builder..metadata = const <String, Object?>{});
  }

  /// Returns whether a metadata key exists.
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

  /// Returns an immutable metadata view.
  Map<String, Object?> get metadataView => Map<String, Object?>.unmodifiable(metadata);

  /// Validates this configuration.
  List<String> validate() {
    final errors = <String>[];

    if (!FaultType.isValid(type.value)) {
      errors.add('type must not be empty.');
    }

    if (probability < 0.0 || probability > 1.0) {
      errors.add('probability must be between 0.0 and 1.0.');
    }

    if (delay != null && delay!.isNegative) {
      errors.add('delay must not be negative.');
    }

    if (duration != null && duration!.isNegative) {
      errors.add('duration must not be negative.');
    }

    if (maxOccurrences != null && maxOccurrences! <= 0) {
      errors.add('maxOccurrences must be greater than 0.');
    }

    return List<String>.unmodifiable(errors);
  }

  /// Validates this configuration and throws if invalid.
  void validateOrThrow() {
    final errors = validate();

    if (errors.isEmpty) {
      return;
    }

    throw StateError('Invalid FaultConfig: ${errors.join(' ')}');
  }

  void _validateProbability(double value) {
    if (value < 0.0 || value > 1.0) {
      throw ArgumentError.value(value, 'value', 'probability must be between 0.0 and 1.0.');
    }
  }
}
