import 'log_level.dart';
import 'log_category.dart';
import 'player_logger.dart';
import 'log_console_sink.dart';

/// The framework-wide logging entry point.
///
/// Every module logs through this hub instead of holding a logger
/// reference. That is a deliberate trade: a logger injected through every
/// constructor would touch every public signature in the framework, and
/// the point of this log is to answer *cross-module* questions — "why did
/// playback end up on this backend?" — which single-module plumbing
/// cannot answer anyway.
///
/// ## Configuring it
///
/// One line turns on the decision trail:
///
/// ```dart
/// MediaCoreLog.level = LogLevel.debug;
/// ```
///
/// Or, when only one part of the framework is under investigation:
///
/// ```dart
/// MediaCoreLog.configure(
///   level: LogLevel.warning,
///   categories: <LogCategory, LogLevel>{
///     LogCategory.fallback: LogLevel.debug,
///     LogCategory.recovery: LogLevel.debug,
///   },
/// );
/// ```
///
/// Routing records somewhere other than the console:
///
/// ```dart
/// final memory = MemoryLogSink();
/// MediaCoreLog.configure(sink: memory.call);
/// // ... reproduce the problem ...
/// print(memory.messagesFor(LogCategory.fallback));
/// ```
///
/// Everything is reversible through [reset].
///
/// ## Levels
///
/// [LogLevel] orders severity; a record is emitted when its level is at
/// least as severe as the effective minimum for its category. The
/// per-category override map exists because debugging one broken engine
/// should not require drowning in another module's trace output.
///
/// Cost when disabled: one enum comparison per dropped record. Nothing is
/// built — no strings, no maps — until a level check passes, which is why
/// call sites pass values instead of pre-formatted messages.
abstract final class MediaCoreLog {
  MediaCoreLog._();

  /// Level used before any explicit configuration.
  ///
  /// `info` keeps normal operation quiet: the framework logs decisions
  /// (which backend, which recovery step), not bookkeeping.
  static const LogLevel defaultLevel = LogLevel.info;

  static PlayerLogger _logger = PlayerLogger(
    minimumLevel: defaultLevel,
    sink: consoleLogSink(),
  );

  static final Map<LogCategory, LogLevel> _categoryLevels = <LogCategory, LogLevel>{};

  /// The underlying logger.
  ///
  /// Exposed for consumers that want the record stream or need to hand a
  /// logger to code that already expects one.
  static PlayerLogger get logger => _logger;

  /// Global minimum level.
  ///
  /// A category override wins over this value for that category.
  static LogLevel get level => _logger.minimumLevel;

  /// Changes the global minimum level.
  static set level(LogLevel value) {
    _logger.minimumLevel = value;
  }

  /// Whether logging is switched on at all.
  static bool get enabled => _logger.enabled;

  /// Switches logging on or off without touching levels.
  static set enabled(bool value) {
    _logger.enabled = value;
  }

  /// Stream of emitted records.
  static Stream<PlayerLogRecord> get records => _logger.records;

  /// Per-category level overrides.
  static Map<LogCategory, LogLevel> get categoryLevels => Map<LogCategory, LogLevel>.unmodifiable(_categoryLevels);

  /// Configures the hub in one call.
  ///
  /// [categories] is merged into the existing overrides unless
  /// [replaceCategories] is set, so a caller can enable one category
  /// without having to restate the others.
  static void configure({
    LogLevel? level,
    bool? enabled,
    PlayerLogSink? sink,
    Map<LogCategory, LogLevel>? categories,
    bool replaceCategories = false,
  }) {
    if (level != null) {
      _logger.minimumLevel = level;
    }

    if (enabled != null) {
      _logger.enabled = enabled;
    }

    if (sink != null) {
      _logger.setSink(sink);
    }

    if (categories != null) {
      if (replaceCategories) {
        _categoryLevels.clear();
      }

      _categoryLevels.addAll(categories);
    }
  }

  /// Overrides the level of one category.
  static void setCategoryLevel(LogCategory category, LogLevel level) {
    _categoryLevels[category] = level;
  }

  /// Removes the override of one category.
  static void clearCategoryLevel(LogCategory category) {
    _categoryLevels.remove(category);
  }

  /// Removes every category override.
  static void clearCategoryLevels() {
    _categoryLevels.clear();
  }

  /// Parses a level from its [LogLevelX.name], case-insensitively.
  ///
  /// Accepts the common aliases `warn` and `none`/`off` (`off` maps to
  /// [LogLevel.critical], which silences everything below it). Returns
  /// `null` for an unknown name so a caller can decide whether that is an
  /// error or a fallback.
  static LogLevel? levelFromName(String name) {
    switch (name.trim().toLowerCase()) {
      case 'trace':
        return LogLevel.trace;
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warn':
      case 'warning':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      case 'critical':
      case 'fatal':
        return LogLevel.critical;
      case 'off':
      case 'none':
        return LogLevel.critical;
      default:
        return null;
    }
  }

  /// Sets the level from a name, falling back to [defaultLevel] when the
  /// name is unknown.
  static LogLevel setLevelFromName(String name) {
    final parsed = levelFromName(name) ?? defaultLevel;

    level = parsed;

    return parsed;
  }

  /// Effective minimum level of [category].
  static LogLevel minimumLevelFor(LogCategory category) {
    return _categoryLevels[category] ?? _logger.minimumLevel;
  }

  /// Whether a record of [level] in [category] would be emitted.
  static bool isEnabled(LogCategory category, LogLevel level) {
    if (!_logger.enabled) {
      return false;
    }

    return level.isAtLeast(minimumLevelFor(category));
  }

  /// Emits a record.
  static void log(
    LogLevel level,
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    if (!isEnabled(category, level)) {
      return;
    }

    _logger.log(level, category, message, error: error, stackTrace: stackTrace, fields: fields);
  }

  /// Emits a trace-level record.
  static void trace(
    LogCategory category,
    String message, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    log(LogLevel.trace, category, message, fields: fields);
  }

  /// Emits a debug-level record.
  static void debug(
    LogCategory category,
    String message, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    log(LogLevel.debug, category, message, fields: fields);
  }

  /// Emits an info-level record.
  static void info(
    LogCategory category,
    String message, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    log(LogLevel.info, category, message, fields: fields);
  }

  /// Emits a warning-level record.
  static void warning(
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    log(LogLevel.warning, category, message, error: error, stackTrace: stackTrace, fields: fields);
  }

  /// Emits an error-level record.
  static void error(
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    log(LogLevel.error, category, message, error: error, stackTrace: stackTrace, fields: fields);
  }

  /// Emits a critical-level record.
  static void critical(
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    log(LogLevel.critical, category, message, error: error, stackTrace: stackTrace, fields: fields);
  }

  /// Replaces the logger and returns the previous one.
  static PlayerLogger install(PlayerLogger logger) {
    final previous = _logger;

    _logger = logger;

    return previous;
  }

  /// Restores the default logger, level and category overrides.
  static void reset() {
    _categoryLevels.clear();
    _logger = PlayerLogger(minimumLevel: defaultLevel, sink: consoleLogSink());
  }
}
