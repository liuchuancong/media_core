part of 'media_kit_player_adapter.dart';

/// Engine creation: the caller's native configurations, verbatim.
///
/// The adapter normalises nothing here. `PlayerConfiguration` and
/// `VideoControllerConfiguration` are media_kit's own types — whatever the
/// caller passed is what the engine receives, so every tuning value
/// belongs to the caller. Runtime changes travel as engine options (mpv
/// properties) through `onApplyEngineOptions` instead.
extension _MediaKitEngineConfig on MediaKitPlayerAdapter {
  mkv.VideoController _buildVideoController() {
    return mkv.VideoController(
      player,
      configuration: videoControllerConfiguration ?? const mkv.VideoControllerConfiguration(),
    );
  }

  Future<void> _setNativeProperty(String name, String value) async {
    final native = _player?.platform;

    if (native == null) return;

    try {
      // ignore: avoid_dynamic_calls
      await (native as dynamic).setProperty(name, value);
    } catch (_) {
      // Best-effort.
    }
  }
}
