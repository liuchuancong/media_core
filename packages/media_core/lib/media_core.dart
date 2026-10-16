// GENERATED PACKAGE LIBRARY - DO NOT EDIT.

/// Public entry point for the `media_core` package.
///
/// This library exports the public module libraries that make up
/// the reusable media core architecture.
///
/// Each module owns its own public library:
///
///   `lib/src/core/library.dart`
///   `lib/src/source/library.dart`
///   `lib/src/adapter/library.dart`
///
/// Generated files such as `*.freezed.dart` and `*.g.dart` are never
/// exported directly.
///
/// Internal modules such as `testing` are intentionally excluded.
///
/// Do not edit manually.
library;

// ============================================================================
// Public modules
// ============================================================================

/// PlayerIdentity backend adapter abstraction and adapter lifecycle..
export 'package:media_core/src/adapter/library.dart';

/// Audio focus, session, route, volume and mute management..
export 'package:media_core/src/audio/library.dart';

/// Background execution requests, leases, results and the lease registry..
export 'package:media_core/src/background/library.dart';

/// Debugging and fault-injection infrastructure..
export 'package:media_core/src/bug/library.dart';

/// Memory, disk and cache storage abstractions..
export 'package:media_core/src/cache/library.dart';

/// Protocol-neutral casting: render devices, transport state, controller..
export 'package:media_core/src/casting/library.dart';

/// Composition layer: presentation timeline, segments and cues..
export 'package:media_core/src/composition/library.dart';

/// Mutex, semaphore, locking and concurrency control primitives..
export 'package:media_core/src/concurrency/library.dart';

/// Cross-module player and playback coordination..
export 'package:media_core/src/coordinator/library.dart';

/// Public player API and fundamental player models..
export 'package:media_core/src/core/library.dart';

/// Logging, performance, memory and network diagnostics..
export 'package:media_core/src/diagnostics/library.dart';

/// Error models, classification, formatting and error policies..
export 'package:media_core/src/error/library.dart';

/// PlayerIdentity event definitions, dispatching and subscriptions..
export 'package:media_core/src/event/library.dart';

/// PlayerIdentity and backend factory, registration and selection..
export 'package:media_core/src/factory/library.dart';

/// Backend, line and quality fallback mechanisms..
export 'package:media_core/src/fallback/library.dart';

/// Video geometry, orientation, rotation and display dimensions..
export 'package:media_core/src/geometry/library.dart';

/// Stable cross-module identity and identifier value objects..
export 'package:media_core/src/identity/library.dart';

/// Background-job outcomes and the reporter slot a notification layer registers into..
export 'package:media_core/src/job/library.dart';

/// PlayerIdentity kernel: orchestration root wiring source, adapter, session, playback, recovery, fallback, pool and events..
export 'package:media_core/src/kernel/library.dart';

/// PlayerIdentity, page and application lifecycle management..
export 'package:media_core/src/lifecycle/library.dart';

/// Network abstraction, monitoring, conditions and metrics..
export 'package:media_core/src/network/library.dart';

/// High-level asynchronous and business operations..
export 'package:media_core/src/operation/library.dart';

/// Media source planning: plans, planner contract and defaults..
export 'package:media_core/src/planning/library.dart';

/// Platform capabilities and platform-specific abstractions..
export 'package:media_core/src/platform/library.dart';

/// Playback commands, state, position, duration and options..
export 'package:media_core/src/playback/library.dart';

/// Centralized cross-module player policies..
export 'package:media_core/src/policy/library.dart';

/// PlayerIdentity instance pooling, allocation and recycling..
export 'package:media_core/src/pool/library.dart';

/// Media preloading, warm-up and preload scheduling..
export 'package:media_core/src/preload/library.dart';

/// Fullscreen, picture-in-picture and floating presentation..
export 'package:media_core/src/presentation/library.dart';

/// Quality candidates and live switching continuity..
export 'package:media_core/src/quality/library.dart';

/// Reactive abstractions and stream utilities..
export 'package:media_core/src/reactive/library.dart';

/// Desired-state to actual-state reconciliation..
export 'package:media_core/src/reconciler/library.dart';

/// Recording abstraction, sessions, formats and backends..
export 'package:media_core/src/recording/library.dart';

/// Playback recovery, retry scheduling and recovery state..
export 'package:media_core/src/recovery/library.dart';

/// PlayerIdentity rendering abstraction and rendering state..
export 'package:media_core/src/renderer/library.dart';

/// Decoder, memory, bandwidth and thermal resource management..
export 'package:media_core/src/resource/library.dart';

/// Unified result and asynchronous result abstractions..
export 'package:media_core/src/result/library.dart';
// Composition root: owns adapter + session + per-session controllers.
export 'package:media_core/src/runtime/library.dart';

/// Frame capture: engine capture, surface capture, captured-frame value, file writing..
export 'package:media_core/src/screenshot/library.dart';

/// PlayerIdentity session lifecycle, context, state and operations..
export 'package:media_core/src/session/library.dart';

/// Logical player slot ownership, assignment and state..
export 'package:media_core/src/slot/library.dart';

/// Media source abstraction, metadata, resolution and validation..
export 'package:media_core/src/source/library.dart';

/// Generic state-machine infrastructure and state transitions..
export 'package:media_core/src/state_machine/library.dart';

/// Task execution, scheduling, priority and cancellation..
export 'package:media_core/src/task/library.dart';

/// Generic reusable utility functions and helpers..
export 'package:media_core/src/util/library.dart';

/// PlayerIdentity visibility observation, state and management..
export 'package:media_core/src/visibility/library.dart';
