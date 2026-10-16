/// Memory accounting for media_core.
///
/// Two views of the same thing, both needed:
///
/// - **Declared**: every module reports what it holds (`MediaCoreMemory.of(...)`),
///   so a report can say *who* is using memory. The numbers are estimates —
///   no Dart API knows how many bytes a decoder holds — and the package says so
///   rather than pretending otherwise.
/// - **Measured**: `MemoryMonitor` takes device snapshots (used/available/
///   external bytes) from a platform provider the host installs.
///
/// ```dart
/// // Instrumentation, from inside a module:
/// final _memory = MediaCoreMemory.of(MemoryModule.pool);
/// _memory.add(items: 1, bytes: MemoryEstimates.videoStream720p, note: 'warm player');
///
/// // Policy, before optional work:
/// if (MediaCoreMemory.pressure.shouldStopPreload) return;
///
/// // Diagnostics:
/// MediaCoreMemory.attachDeviceProvider(myPlatformReader);
/// print(MediaCoreMemory.report().describe());
/// ```
///
/// Pressure runs `normal < elevated < critical < emergency`, from the tracked
/// total against `MemoryBudget` (512 MiB, warning at 70%, critical at 85% by
/// default). It is logged under the `memory` category whenever the level moves.
library;

export 'package:media_core_memory/src/account/memory_account.dart';
export 'package:media_core_memory/src/account/memory_budget.dart';
export 'package:media_core_memory/src/account/memory_estimates.dart';
export 'package:media_core_memory/src/account/memory_registry.dart';
export 'package:media_core_memory/src/monitor/memory_monitor.dart';
export 'package:media_core_memory/src/monitor/memory_pressure.dart';
export 'package:media_core_memory/src/monitor/memory_report.dart';
export 'package:media_core_memory/src/monitor/memory_snapshot.dart';
export 'package:media_core_memory/src/runtime/memory_hub.dart';
export 'package:media_core_memory/src/runtime/memory_manager.dart';
export 'package:media_core_memory/src/runtime/memory_module.dart';
