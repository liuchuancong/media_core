/// better_player backend adapter for media_core.
///
/// Supports network (HTTP/HTTPS/HLS/DASH) and file sources. Asset sources
/// are not supported: better_player's setupDataSource has no asset branch.
library;

// The engine this adapter is built on, re-exported so a host reaches it from
// its single dependency on this adapter. The engine's `PlayerEvent` /
// `PlayerEventType` clash with media_core's own event model of the same
// names, so they are hidden from the re-export and surfaced under the
// `BetterPlayerEvent` / `BetterPlayerEventType` aliases instead.
import 'package:better_player/better_player.dart' as better_player;

export 'package:better_player/better_player.dart' hide PlayerEvent, PlayerEventType;
export 'package:media_core_better_player/src/better_player_adapter.dart';
export 'package:media_core_better_player/src/better_player_adapter_factory.dart';

/// The better_player engine's event object, aliased away from media_core's
/// own `PlayerEvent` of the same name.
typedef BetterPlayerEvent = better_player.PlayerEvent;

/// The better_player engine's event type enum, aliased away from media_core's
/// own `PlayerEventType` of the same name.
typedef BetterPlayerEventType = better_player.PlayerEventType;
