import 'dart:async';
import 'presentation_event.dart';
import 'presentation_request.dart';
import 'presentation_capabilities.dart';

/// Platform presentation adapter.
///
/// Connects presentation core with native
/// platform presentation APIs.
///
/// Implementations may use:
///
/// - Android PictureInPicture API
/// - iOS AVPictureInPictureController
/// - Windows window APIs
/// - macOS NSWindow APIs
///
/// Adapter responsibilities:
///
/// - execute platform operations
/// - report presentation events
/// - report capability changes
///
/// Adapter does not:
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
  ///
  /// Examples:
  ///
  /// - PiP permission changed
  /// - window mode changed
  /// - device configuration changed
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
  /// The adapter performs the real
  /// platform operation.
  Future<void> apply(PresentationRequest request);

  /// Refreshes platform capabilities.
  Future<void> refreshCapabilities();

  /// Releases resources.
  Future<void> dispose();
}
