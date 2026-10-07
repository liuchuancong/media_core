part of 'media_kit_player_adapter.dart';

/// The mpv command that writes a list-valued option.
///
/// A list option cannot be written the way scalars are.
/// `NativePlayer.setProperty` is `mpv_set_property_string`, and handing it a
/// comma-joined value does not split it: `glsl-shaders="a.glsl,b.glsl"` makes
/// mpv open one shader file literally named `a.glsl,b.glsl`, which on Windows
/// fails as an over-long path and reaches the host as a playback error for
/// whatever source happened to be open. `change-list` is mpv's documented
/// mutation for list options, and its value is the comma-separated entry list.
///
/// An empty [entries] clears the option: `set` with an empty value would be
/// one empty entry, while `clr` is the engine's own answer to "no entries".
List<String> mpvListOptionCommand(String key, List<Object?> entries) {
  final values = entries.map((Object? entry) => entry == null ? '' : '$entry').toList();

  if (values.isEmpty) {
    return <String>['change-list', key, 'clr', ''];
  }

  return <String>['change-list', key, 'set', values.join(',')];
}

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

  /// Writes one engine option in the shape its value has.
  ///
  /// This is the only place a value's type is interpreted, so the two call
  /// sites that deliver options — the stash replay at engine creation and
  /// the live apply — cannot drift into different dialects. A [List] value
  /// is a list option and travels as a command; everything else is the
  /// scalar property write.
  Future<bool> _applyNativeOption(EngineOption option) async {
    final value = option.value;

    if (value is List) {
      return _runNativeCommand(mpvListOptionCommand(option.key, value));
    }

    return _setNativeProperty(option.key, _mpvOptionValue(value));
  }

  /// Runs one mpv command verbatim and reports whether the engine took it.
  ///
  /// The same honesty rule as [_setNativeProperty]: a command the engine
  /// refused is `false`, so the caller reports the option as unsupported
  /// instead of claiming the tuning landed.
  Future<bool> _runNativeCommand(List<String> command) async {
    final native = _player?.platform;

    if (native == null) return false;

    try {
      // ignore: avoid_dynamic_calls
      await (native as dynamic).command(command);
      return true;
    } catch (error) {
      MediaCoreLog.warning(
        LogCategory.player,
        'mpv rejected command "${command.join(' ')}": $error',
        error: error,
      );
      return false;
    }
  }
}
