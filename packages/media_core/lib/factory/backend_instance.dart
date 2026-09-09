/// Runtime instance of a player backend.
///
/// A [BackendInstance] represents one created backend
/// runtime.
///
/// It is created by [BackendFactory].
///
/// Responsibilities:
///
/// - represent backend lifecycle
/// - initialize backend runtime
/// - release backend resources
///
/// It does not:
///
/// - select backend
/// - store backend metadata
/// - manage player session
///
/// Those belong to:
///
/// - BackendSelector
/// - BackendDescriptor
/// - PlayerSession
abstract interface class BackendInstance {
  /// Backend identifier.
  ///
  /// Usually matches:
  ///
  /// BackendDescriptor.id
  String get id;

  /// Whether backend has been initialized.
  bool get initialized;

  /// Whether backend has been disposed.
  bool get disposed;

  /// Initializes backend runtime.
  ///
  /// Called before playback.
  Future<void> initialize();

  /// Releases backend resources.
  ///
  /// After dispose:
  ///
  /// - instance cannot be reused
  Future<void> dispose();
}
