import 'backend_instance.dart';

/// Factory for creating player backend instances.
///
/// A [BackendFactory] creates runtime backend objects.
///
/// Responsibilities:
///
/// - create backend instance
/// - initialize backend runtime
/// - provide backend lifecycle entry
///
/// It does not:
///
/// - select backend
/// - manage backend registry
/// - decide fallback strategy
///
/// Those belong to:
///
/// - BackendSelector
/// - BackendRegistry
/// - FallbackManager
abstract interface class BackendFactory {
  /// Creates a backend instance.
  ///
  /// Each call should normally return
  /// an independent backend runtime.
  BackendInstance create();

  /// Backend warm-up.
  ///
  /// Used for:
  ///
  /// - preload
  /// - decoder initialization
  /// - resource preparation
  ///
  /// Default implementation does nothing.
  Future<void> warmUp() async {}

  /// Releases factory resources.
  ///
  /// Factory itself normally lives
  /// for application lifetime.
  Future<void> dispose() async {}
}
