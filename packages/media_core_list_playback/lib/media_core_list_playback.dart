/// List playback for media_core.
///
/// An ordered list played in one window: swipe up for the next item, swipe down
/// for the previous one, and each item resumes where it was left — so returning
/// to something watched earlier continues instead of restarting.
///
/// ```dart
/// final controller = PlaybackListController(
///   player: KernelPlaybackListPlayer(handle),
///   items: entries,
///   store: MyPersistentProgressStore(),
/// );
/// await controller.open(index: 0);
/// await controller.next();        // saves the current position first
/// ```
///
/// The controller drives a player it does not own; the host owns the player,
/// the list surface and the gestures.
library;

export 'src/playback_list_config.dart';
export 'src/playback_list_controller.dart';
export 'src/playback_list_item.dart';
export 'src/playback_list_player.dart';
export 'src/playback_progress_store.dart';
