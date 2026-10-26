/// Logical category of an audio output route.
///
/// The enum intentionally describes capabilities at a coarse level rather
/// than mirroring platform-specific device types.
enum AudioRouteKind {
  /// Platform-managed or otherwise unknown route.
  unknown,

  /// Built-in speaker.
  speaker,

  /// Built-in earpiece.
  earpiece,

  /// Wired headset or headphones.
  wiredHeadset,

  /// Bluetooth audio device.
  bluetooth,

  /// USB audio device.
  usb,

  /// HDMI or display audio output.
  hdmi,

  /// Cast or remote network audio output.
  remote,

  /// Other external audio output.
  external,
}
