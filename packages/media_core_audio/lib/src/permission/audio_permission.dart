/// A runtime permission the music module can need.
///
/// Deliberately a small, platform-mapped set rather than a mirror of every
/// platform's permission names: a host asks for what it *does*, and this layer
/// knows which platform permission that means.
enum AudioPermission {
  /// Post media notifications (Android 13+).
  ///
  /// Without it the media notification silently never appears — playback and
  /// the lock screen entry still work, which is exactly why this is worth
  /// asking for explicitly instead of wondering why the notification is gone.
  notifications,

  /// Read the device's audio files (Android 13+; storage on older releases).
  ///
  /// Needed by `LocalMusicSource` and by any host that scans the device for
  /// music. Playback of streamed or app-private files does not need it.
  mediaLibrary,

  /// Draw over other applications: the desktop-lyric overlay.
  ///
  /// Grantable only from a system settings screen, never from a dialog.
  desktopLyricOverlay,
}
