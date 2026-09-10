// GENERATED PACKAGE LIBRARY - DO NOT EDIT.

/// Public entry point for the `media_core` package.
///
/// This library exports the public module libraries that make up
/// the reusable media core architecture.
///
/// Each module owns its own public library:
///
///   `lib/core/library.dart`
///   `lib/source/library.dart`
///   `lib/adapter/library.dart`
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

/// Player backend adapter abstraction and adapter lifecycle..
export 'adapter/library.dart';

/// Audio focus, session, route, volume and mute management..
export 'audio/library.dart';

/// Debugging and fault-injection infrastructure..
export 'bug/library.dart';

/// Memory, disk and cache storage abstractions..
export 'cache/library.dart';

/// Mutex, semaphore, locking and concurrency control primitives..
export 'concurrency/library.dart';

/// Cross-module player and playback coordination..
export 'coordinator/library.dart';

/// Public player API and fundamental player models..
export 'core/library.dart';

/// Logging, performance, memory and network diagnostics..
export 'diagnostics/library.dart';

/// Error models, classification, formatting and error policies..
export 'error/library.dart';

/// Player event definitions, dispatching and subscriptions..
export 'event/library.dart';

/// Player and backend factory, registration and selection..
export 'factory/library.dart';

/// Backend, line and quality fallback mechanisms..
export 'fallback/library.dart';

/// Video geometry, orientation, rotation and display dimensions..
export 'geometry/library.dart';

/// Stable cross-module identity and identifier value objects..
export 'identity/library.dart';

/// Player, page and application lifecycle management..
export 'lifecycle/library.dart';

/// Network abstraction, monitoring, conditions and metrics..
export 'network/library.dart';

/// High-level asynchronous and business operations..
export 'operation/library.dart';

/// Platform capabilities and platform-specific abstractions..
export 'platform/library.dart';

/// Playback commands, state, position, duration and options..
export 'playback/library.dart';

/// Centralized cross-module player policies..
export 'policy/library.dart';

/// Player instance pooling, allocation and recycling..
export 'pool/library.dart';

/// Media preloading, warm-up and preload scheduling..
export 'preload/library.dart';

/// Fullscreen, picture-in-picture and floating presentation..
export 'presentation/library.dart';

/// Reactive abstractions and stream utilities..
export 'reactive/library.dart';

/// Desired-state to actual-state reconciliation..
export 'reconciler/library.dart';

/// Recording abstraction, sessions, formats and backends..
export 'recording/library.dart';

/// Playback recovery, retry scheduling and recovery state..
export 'recovery/library.dart';

/// Player rendering abstraction and rendering state..
export 'renderer/library.dart';

/// Decoder, memory, bandwidth and thermal resource management..
export 'resource/library.dart';

/// Unified result and asynchronous result abstractions..
export 'result/library.dart';

/// Player session lifecycle, context, state and operations..
export 'session/library.dart';

/// Logical player slot ownership, assignment and state..
export 'slot/library.dart';

/// Media source abstraction, metadata, resolution and validation..
export 'source/library.dart';

/// Generic state-machine infrastructure and state transitions..
export 'state_machine/library.dart';

/// Task execution, scheduling, priority and cancellation..
export 'task/library.dart';

/// Generic reusable utility functions and helpers..
export 'util/library.dart';

/// Player visibility observation, state and management..
export 'visibility/library.dart';
