/// Levelled logging for media_core.
///
/// One logger, per-module levels and pluggable sinks:
///
/// ```dart
/// MediaCoreLog.level = LogLevel.debug;                 // everything at debug and above
/// MediaCoreLog.setCategoryLevel(LogCategory.playback, LogLevel.trace);  // one module louder
/// MediaCoreLog.addSink(LogFileSink(File('${dir}/media_core.log')));      // and to a file
///
/// MediaCoreLog.playback('open', fields: {'uri': uri}); // tagged with the module
/// LogScope.run({'roomId': roomId}, () => ...);         // everything inside carries the room
/// ```
///
/// Levels run `trace < debug < info < warning < error < critical`, plus
/// `nothing` to silence a category. The default level is [LogLevel.nothing]:
/// logging is opt-in, so a shipping app pays nothing until a developer or a bug
/// report turns it on.
///
/// Every package in the project logs under its own [LogCategory], which is what
/// makes "turn up playback, leave the rest alone" possible while debugging.
library;

export 'src/log_category.dart';
export 'src/log_console_sink.dart';
export 'src/log_file_sink.dart';
export 'src/log_filter.dart';
export 'src/log_formatter.dart';
export 'src/log_level.dart';
export 'src/log_module.dart';
export 'src/log_scope.dart';
export 'src/media_core_log.dart';
export 'src/player_logger.dart';
