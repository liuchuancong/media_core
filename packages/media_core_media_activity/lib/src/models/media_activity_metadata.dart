import 'package:flutter/foundation.dart';

/// Static attributes of one Media Activity (spec §7.2).
///
/// Values here stay stable for the activity's lifetime; a track change
/// updates or recreates the activity instead of letting stale song
/// information linger. [artworkKey] names a file the app placed in the App
/// Group container — never inline image data (spec §7.4, §12).
@immutable
final class MediaActivityMetadata {
  /// Creates the metadata for one playback session.
  const MediaActivityMetadata({
    required this.sessionId,
    required this.title,
    this.artist = '',
    this.album,
    this.artworkKey,
  });

  /// Identifies one playback session; the native manager refuses a second
  /// activity with the same id.
  final String sessionId;

  /// Song title (or the live/video title once those media types ship).
  final String title;

  /// Artist; empty string when unknown — never a null-vs-empty fork.
  final String artist;

  /// Album; nullable because many live streams have none.
  final String? album;

  /// Key of the artwork file in the App Group container (content-hash name).
  /// Null shows the host's default artwork on the lock screen.
  final String? artworkKey;

  @override
  bool operator ==(Object other) =>
      other is MediaActivityMetadata &&
      other.sessionId == sessionId &&
      other.title == title &&
      other.artist == artist &&
      other.album == album &&
      other.artworkKey == artworkKey;

  @override
  int get hashCode => Object.hash(sessionId, title, artist, album, artworkKey);

  @override
  String toString() =>
      'MediaActivityMetadata($sessionId, $title — $artist'
      '${album == null ? '' : ', $album'})';
}
