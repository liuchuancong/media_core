import 'player_adapter_registry.dart';
import '../source/source_descriptor.dart';
import 'player_adapter_capabilities.dart';

/// Selects the best player adapter.
///
/// [PlayerAdapterSelector] decides which backend
/// should handle a source.
///
/// Responsibilities:
///
/// - evaluate adapter capabilities
/// - rank available adapters
/// - provide fallback candidates
///
/// It does not:
///
/// - create adapter instances
/// - manage adapter lifecycle
/// - execute playback
///
/// Those belong to:
///
/// - PlayerAdapterFactory
/// - PlayerAdapter
final class PlayerAdapterSelector {
  /// Creates selector.
  const PlayerAdapterSelector(this.registry);

  /// Adapter registry.
  final PlayerAdapterRegistry registry;

  /// Selects best adapter.
  ///
  /// Returns null when no adapter matches.
  PlayerAdapterRegistration? select(SourceDescriptor source) {
    final candidates = candidatesFor(source);

    if (candidates.isEmpty) {
      return null;
    }

    return candidates.first;
  }

  /// Returns all compatible adapters.
  ///
  /// Ordered by priority.
  List<PlayerAdapterRegistration> candidatesFor(SourceDescriptor source) {
    final candidates = registry.registrations.where((registration) => _supports(registration, source)).toList();

    candidates.sort((a, b) => b.priority.compareTo(a.priority));

    return candidates;
  }

  /// Checks adapter compatibility.
  bool _supports(PlayerAdapterRegistration registration, SourceDescriptor source) {
    if (!registration.enabled) {
      return false;
    }

    final capabilities = registration.capabilities;

    if (source.live && !capabilities.supportsLive) {
      return false;
    }

    if (source.seekable && !capabilities.supportsSeek) {
      return false;
    }

    if (!_supportsProtocol(capabilities, source.protocol.name)) {
      return false;
    }

    if (!_supportsFormat(capabilities, source.format.name)) {
      return false;
    }

    return true;
  }

  bool _supportsProtocol(PlayerAdapterCapabilities capabilities, String protocol) {
    if (capabilities.supportedProtocols.isEmpty) {
      return true;
    }

    return capabilities.supportsProtocol(protocol);
  }

  bool _supportsFormat(PlayerAdapterCapabilities capabilities, String format) {
    if (capabilities.supportedFormats.isEmpty) {
      return true;
    }

    return capabilities.supportsFormat(format);
  }
}
