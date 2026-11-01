/// The renderer's transport state, as UPnP spells it.
enum DlnaTransportState {
  /// No media is loaded (`NO_MEDIA_PRESENT`).
  noMediaPresent,

  /// Loaded and stopped (`STOPPED`).
  stopped,

  /// Playing (`PLAYING`).
  playing,

  /// Paused (`PAUSED_PLAYBACK`).
  paused,

  /// Moving between states (`TRANSITIONING`).
  transitioning,

  /// The device said nothing this package recognizes (including
  /// `NOT_IMPLEMENTED`, which devices send when a field is irrelevant).
  unknown;

  /// Maps a UPnP `CurrentTransportState` value; anything unrecognized
  /// — or absent — becomes [unknown] rather than throwing.
  static DlnaTransportState fromUpnp(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'NO_MEDIA_PRESENT':
        return noMediaPresent;
      case 'STOPPED':
        return stopped;
      case 'PLAYING':
        return playing;
      case 'PAUSED_PLAYBACK':
      case 'PAUSED_RECORDING':
        return paused;
      case 'TRANSITIONING':
        return transitioning;
      default:
        return unknown;
    }
  }
}
