import '../platform/platform_capabilities.dart';
import '../platform/platform_info.dart';
import '../platform/platform_provider.dart';
import '../platform/platform_type.dart';

/// Scriptable [PlatformProvider] for tests.
final class FakePlatformProvider implements PlatformProvider {
  /// Creates a fake provider.
  FakePlatformProvider({
    PlatformType? type,
    PlatformInfo? info,
    PlatformCapabilities? capabilities,
  })  : _type = type ?? PlatformType.unknown,
        _info = info ??
            PlatformInfo(
              type: type ?? PlatformType.unknown,
              name: 'FakeDevice',
              version: '1.0.0',
            ),
        _capabilities = capabilities ?? const PlatformCapabilities();

  PlatformType _type;
  PlatformInfo _info;
  PlatformCapabilities _capabilities;
  bool _ready = false;

  @override
  PlatformType get type => _type;

  @override
  PlatformInfo get info => _info;

  @override
  PlatformCapabilities get capabilities => _capabilities;

  @override
  bool get isReady => _ready;

  /// Marks the provider as ready.
  void markReady() => _ready = true;

  /// Replaces the platform type.
  void updateType(PlatformType type) => _type = type;

  /// Replaces the platform info.
  void updateInfo(PlatformInfo info) => _info = info;

  /// Replaces the capabilities.
  void updateCapabilities(PlatformCapabilities capabilities) => _capabilities = capabilities;
}
