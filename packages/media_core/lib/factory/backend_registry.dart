import 'backend_descriptor.dart';

/// Registry of available player backends.
///
/// [BackendRegistry] stores backend descriptors
/// and provides lookup operations.
///
/// Responsibilities:
///
/// - register backend
/// - remove backend
/// - query backend descriptors
/// - provide backend candidates
///
/// It does not:
///
/// - create backend instances
/// - select best backend
/// - execute playback
///
/// Those belong to:
///
/// - BackendFactory
/// - BackendSelector
final class BackendRegistry {
  /// Creates an empty registry.
  BackendRegistry();

  final Map<String, BackendDescriptor> _backends = <String, BackendDescriptor>{};

  /// Number of registered backends.
  int get length {
    return _backends.length;
  }

  /// Whether registry is empty.
  bool get isEmpty {
    return _backends.isEmpty;
  }

  /// Whether registry has backend.
  bool contains(String id) {
    return _backends.containsKey(id);
  }

  /// Registers a backend.
  ///
  /// Existing backend with same id
  /// will be replaced.
  void register(BackendDescriptor descriptor) {
    _backends[descriptor.id] = descriptor;
  }

  /// Removes a backend.
  ///
  /// Returns removed descriptor.
  BackendDescriptor? unregister(String id) {
    return _backends.remove(id);
  }

  /// Gets backend descriptor.
  BackendDescriptor? get(String id) {
    return _backends[id];
  }

  /// Requires backend descriptor.
  ///
  /// Throws when backend does not exist.
  BackendDescriptor require(String id) {
    final backend = _backends[id];

    if (backend == null) {
      throw StateError('Backend not registered: $id');
    }

    return backend;
  }

  /// Returns all descriptors.
  List<BackendDescriptor> get all {
    return List.unmodifiable(_backends.values);
  }

  /// Returns enabled backends.
  List<BackendDescriptor> get enabled {
    return _backends.values.where((backend) => backend.enabled).toList(growable: false);
  }

  /// Clears registry.
  void clear() {
    _backends.clear();
  }

  /// Removes disabled backends.
  void removeDisabled() {
    _backends.removeWhere((_, backend) => !backend.enabled);
  }

  /// Finds backends supporting platform.
  List<BackendDescriptor> findByPlatform(String platform) {
    return enabled.where((backend) => backend.supportsPlatform(platform)).toList(growable: false);
  }

  @override
  String toString() {
    return 'BackendRegistry('
        'count=${_backends.length}'
        ')';
  }
}
