import 'package:media_core/src/adapter/select/player_adapter_factory.dart';
import 'package:media_core/src/core/model/player_identity.dart';
import 'package:media_core/src/identity/player_id.dart';
import 'package:media_core/src/identity/session_id.dart';
import 'package:media_core/src/models/adapter/library.dart';
import 'package:media_core/src/testing/fake/fake_player.dart';
import 'package:media_core/src/testing/fake/fake_player_adapter.dart';

/// Convenience builders for players and adapters in tests.
final class TestPlayerFactory {
  const TestPlayerFactory._();

  /// Builds a [PlayerIdentity] with a deterministic id from [seed].
  static PlayerIdentity player(int seed) => FakePlayer.fromSeed(seed).player;

  /// Builds [count] distinct players.
  static List<PlayerIdentity> players(int count) {
    return List<PlayerIdentity>.generate(count, TestPlayerFactory.player, growable: false);
  }

  /// Builds a [PlayerId] from a raw string.
  static PlayerId playerId(String value) => PlayerId(value);

  /// Builds a minimal adapter context for [playerId].
  static PlayerAdapterContext context({String? playerId, String? sessionId}) {
    return PlayerAdapterContext.basic(
      playerId: PlayerId(playerId ?? 'test-player'),
      sessionId: SessionId(sessionId ?? 'test-session'),
    );
  }

  /// Builds a default fake adapter.
  static FakePlayerAdapter fakeAdapter() => FakePlayerAdapter();

  /// Builds a core [PlayerAdapterFactory] that creates fake adapters.
  static DefaultPlayerAdapterFactory fakeAdapterFactory() {
    return DefaultPlayerAdapterFactory()..register('fake', FakePlayerAdapter.new);
  }
}
