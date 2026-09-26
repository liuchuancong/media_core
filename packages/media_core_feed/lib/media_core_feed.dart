/// Vertical feed (TikTok/Douyin-style) playback on top of the player kernel.
///
/// One shared player is re-pointed at the item the viewer swipes to, with the
/// next item optionally preloaded, so a swipe is a source change rather than a
/// player lifecycle change.
library;

export 'src/feed_config.dart';
export 'src/feed_player_controller.dart';
