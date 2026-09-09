import 'platform_type.dart';
import 'platform_info.dart';
import 'platform_capabilities.dart';

/// Provides platform runtime information.
///
/// [PlatformProvider] is the abstraction layer
/// between media core and host platform.
///
/// Responsibilities:
///
/// - provide platform type
/// - provide platform information
/// - provide platform capabilities
///
/// It does not:
///
/// - access native APIs directly
/// - initialize player backend
///
/// Those belong to:
///
/// - PlatformInfo
/// - BackendFactory
abstract interface class PlatformProvider {
  /// Current platform type.
  PlatformType get type;

  /// Platform information.
  PlatformInfo get info;

  /// Platform capabilities.
  PlatformCapabilities get capabilities;

  /// Whether provider is ready.
  bool get isReady;
}
