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

import 'package:media_core_logging/media_core_logging.dart' show LogCategory, LogLevel;

export 'package:media_core_logging/src/logger/log_module.dart';
export 'package:media_core_logging/src/logger/log_scope.dart';
export 'package:media_core_logging/src/logger/media_core_log.dart';
export 'package:media_core_logging/src/logger/player_logger.dart';
export 'package:media_core_logging/src/policy/log_filter.dart';
export 'package:media_core_logging/src/policy/log_formatter.dart';
export 'package:media_core_logging/src/record/log_category.dart';
export 'package:media_core_logging/src/record/log_level.dart';
export 'package:media_core_logging/src/sink/log_file_sink.dart';
export 'package:media_core_logging/src/sink/memory_log_sink.dart';
