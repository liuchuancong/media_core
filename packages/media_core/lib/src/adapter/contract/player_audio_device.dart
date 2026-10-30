/// One audio output device the engine can send its sound to.
///
/// The list is the engine's own answer — media_kit reads mpv's
/// `audio-device-list` — so a backend or platform without a device picker
/// simply reports an empty list and the settings surface hides the row.
/// Selecting a device is an engine option (`audio-device`, the [name]
/// here) through the ordinary engine-option route, so a choice survives
/// engine rebuilds the same way every other option does.
final class PlayerAudioDevice {
  /// Creates one device entry.
  const PlayerAudioDevice({required this.name, required this.description, required this.selected});

  /// The engine's identifier for the device — the value `audio-device`
  /// takes, `auto` for the engine's own default.
  final String name;

  /// The human-readable device name the engine reported.
  final String description;

  /// Whether the engine is currently sending sound to this device.
  final bool selected;
}
