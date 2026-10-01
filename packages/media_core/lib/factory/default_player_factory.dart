import 'package:media_core/core/player_identity.dart';
import 'package:media_core/factory/player_factory.dart';
import 'package:media_core/factory/player_factory_config.dart';

/// Default [PlayerFactory] implementation.
///
/// Creates logical [PlayerIdentity] identities. Adapter creation and
/// wiring belong to the kernel layer (`PlayerKernel.create`).
final class DefaultPlayerFactory implements PlayerFactory {
  /// Creates the factory.
  const DefaultPlayerFactory();

  @override
  PlayerIdentity create({PlayerFactoryConfig? config}) {
    return PlayerIdentity.create();
  }
}
