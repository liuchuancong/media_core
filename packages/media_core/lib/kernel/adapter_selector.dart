import '../source/player_source.dart';
import '../source/source_protocol.dart';
import '../source/source_format.dart';
import '../adapter/player_adapter_registry.dart';

/// Selects the best adapter registration for a media source.
///
/// [PlayerAdapterSelector] bridges the adapter registry and
/// concrete adapter creation. It scores every enabled
/// [PlayerAdapterRegistration] against a [PlayerSource] and
/// returns the best match.
///
/// Responsibilities:
///
/// - score adapters against a source
/// - honour explicit preferences
/// - expose candidate ordering
///
/// It does not:
///
/// - create adapter instances
/// - initialize adapters
/// - perform fallback at runtime
///
/// Those belong to:
///
/// - PlayerAdapterFactory
/// - PlayerAdapter
/// - PlayerKernel
final class PlayerAdapterSelector {
  /// Creates a selector reading from [registry].
  const PlayerAdapterSelector(this.registry);

  /// Registry of available adapters.
  final PlayerAdapterRegistry registry;

  /// Returns the best registration for [source], or `null` when
  /// no enabled adapter is registered.
  ///
  /// When [preferredId] names a registered and enabled adapter it
  /// wins unconditionally.
  PlayerAdapterRegistration? select(PlayerSource source, {String? preferredId}) {
    if (preferredId != null) {
      final preferred = registry.get(preferredId);
      if (preferred != null && preferred.enabled) {
        return preferred;
      }
    }

    final candidates = candidatesFor(source);
    if (candidates.isEmpty) {
      return null;
    }

    PlayerAdapterRegistration? best;
    var bestScore = -1;

    for (final candidate in candidates) {
      final candidateScore = score(candidate, source);
      if (candidateScore > bestScore) {
        bestScore = candidateScore;
        best = candidate;
      }
    }

    return best;
  }

  /// Returns the best registration for [source].
  ///
  /// Throws [StateError] when no enabled adapter can play [source].
  PlayerAdapterRegistration require(PlayerSource source, {String? preferredId}) {
    final selected = select(source, preferredId: preferredId);
    if (selected == null) {
      throw StateError(
        'No enabled player adapter can handle source '
        '"${source.uri}" (protocol: ${source.protocol.name}, format: ${source.format.name}).',
      );
    }
    return selected;
  }

  /// Returns enabled registrations able to handle [source],
  /// ordered from best to worst match.
  List<PlayerAdapterRegistration> candidatesFor(PlayerSource source) {
    final capable = registry.registrations.where((registration) => registration.enabled).toList()
      ..sort((a, b) {
        final byScore = score(b, source).compareTo(score(a, source));
        if (byScore != 0) return byScore;
        return b.priority.compareTo(a.priority);
      });
    return capable;
  }

  /// Scores one registration against [source].
  ///
  /// Weights:
  ///
  /// - registration priority: as registered (tie-breaker baseline)
  /// - protocol match: +40
  /// - format match: +30
  /// - live support for live sources: +10
  int score(PlayerAdapterRegistration registration, PlayerSource source) {
    var score = registration.priority;
    final capabilities = registration.capabilities;

    if (source.protocol != SourceProtocol.unknown && capabilities.supportsProtocol(source.protocol.name)) {
      score += 40;
    }

    if (source.format != SourceFormat.unknown && capabilities.supportsFormat(source.format.name)) {
      score += 30;
    }

    if (source.isLive && capabilities.supportsLive) {
      score += 10;
    }

    return score;
  }
}
