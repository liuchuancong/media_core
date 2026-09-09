import 'backend_factory.dart';
import 'backend_capabilities.dart';

/// Describes a player backend.
///
/// A [BackendDescriptor] contains metadata about
/// a backend implementation.
///
/// It is registered inside [BackendRegistry]
/// and consumed by [BackendSelector].
///
/// Responsibilities:
///
/// - identify backend
/// - describe capabilities
/// - provide backend factory
///
/// It does not:
///
/// - create player directly
/// - manage backend lifecycle
/// - execute playback
///
/// Those belong to:
///
/// - BackendFactory
/// - BackendInstance
final class BackendDescriptor {

  /// Creates a backend descriptor.
  const BackendDescriptor({
    required this.id,
    required this.name,
    required this.factory,
    required this.capabilities,

    this.version,
    this.priority = 0,
    this.enabled = true,
  });


  /// Unique backend identifier.
  ///
  /// Example:
  ///
  /// - media_kit
  /// - vlc
  /// - exoplayer
  final String id;



  /// Human readable backend name.
  ///
  /// Example:
  ///
  /// MediaKit
  final String name;



  /// Backend version.
  final String? version;



  /// Factory used to create backend instances.
  final BackendFactory factory;



  /// Backend capabilities.
  final BackendCapabilities capabilities;



  /// Selection priority.
  ///
  /// Higher value means preferred.
  final int priority;



  /// Whether backend can participate
  /// in selection.
  final bool enabled;



  /// Whether backend supports live playback.
  bool get supportsLive {
    return capabilities.live;
  }



  /// Whether backend supports local files.
  bool get supportsLocalFile {
    return capabilities.localFile;
  }



  /// Whether backend supports network streams.
  bool get supportsNetwork {
    return capabilities.networkStream;
  }



  /// Whether backend is available.
  bool get available {
    return enabled;
  }



  /// Checks whether backend supports platform.
  bool supportsPlatform(
    String platform,
  ) {

    return capabilities.supportsPlatform(
      platform,
    );

  }



  /// Creates a copy with changed values.
  BackendDescriptor copyWith({

    String? id,
    String? name,
    String? version,

    BackendFactory? factory,

    BackendCapabilities? capabilities,

    int? priority,

    bool? enabled,

  }) {

    return BackendDescriptor(

      id: id ?? this.id,

      name: name ?? this.name,

      version: version ?? this.version,

      factory:
          factory ?? this.factory,

      capabilities:
          capabilities ?? this.capabilities,

      priority:
          priority ?? this.priority,

      enabled:
          enabled ?? this.enabled,

    );

  }



  @override
  String toString() {

    return 'BackendDescriptor('
        'id=$id, '
        'name=$name, '
        'priority=$priority, '
        'enabled=$enabled'
        ')';

  }

}