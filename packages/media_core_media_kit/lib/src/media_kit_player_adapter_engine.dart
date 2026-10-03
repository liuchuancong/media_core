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

  /// Writes one mpv property and reports whether the engine took it.
  ///
  /// A `null` platform means there is no native surface at all (web, or a
  /// player that has not been created yet) and a rejected property is the
  /// engine's own answer. Both have to reach the caller: an option
  /// reported as applied while it was dropped leaves the host believing
  /// its tuning took effect, which is the failure this class exists to
  /// avoid.
  Future<bool> _setNativeProperty(String name, String value) async {
    final native = _player?.platform;

    if (native == null) return false;

    try {
      // ignore: avoid_dynamic_calls
      await (native as dynamic).setProperty(name, value);
      return true;
    } catch (error) {
      MediaCoreLog.warning(
        LogCategory.player,
        'mpv rejected property "$name": $error',
        error: error,
      );
      return false;
    }
  }
}
