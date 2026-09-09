import 'dart:async';
import 'presentation_event.dart';
import 'presentation_request.dart';
import 'presentation_capabilities.dart';

/// Platform presentation adapter.
///
/// Connects presentation core with native
/// platform presentation APIs.
///
/// Responsibilities:
///
/// - execute platform operations
/// - report presentation events
/// - report capability changes
///
/// Does not:
///
/// - own lifecycle state
/// - store presentation state
/// - decide transitions
abstract interface class PresentationAdapter {
  /// Current platform capabilities.
  PresentationCapabilities get capabilities;

  /// Capability change stream.
  ///
  /// Emits when platform support changes.
  Stream<PresentationCapabilities> get capabilityChanges;

  /// Platform presentation events.
  ///
  /// Examples:
  ///
  /// - fullscreen entered
  /// - PiP entered
  /// - floating window closed
  Stream<PresentationEvent> get events;

  /// Applies presentation request.
  ///
  /// Executes real native operation.
  Future<void> apply(PresentationRequest request);

  /// Exits current presentation.
  ///
  /// Examples:
  ///
  /// - exit fullscreen
  /// - leave PiP
  /// - close floating window
  Future<void> exit();

  /// Refreshes platform capabilities.
  Future<void> refreshCapabilities();

  /// Releases resources.
  Future<void> dispose();
}
