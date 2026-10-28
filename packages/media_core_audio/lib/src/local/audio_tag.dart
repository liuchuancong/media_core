import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

/// The tags an audio file carries about itself.
///
/// Every field is optional and untrimmed: a tag that is present but empty is
/// still the file's answer, and turning it into "no tag" here would make the
/// reader lie about what it saw. Hosts decide what to show.
@immutable
final class AudioTag {
  /// Creates a tag set.
  const AudioTag({
    this.title,
    this.artist,
    this.album,
    this.trackNumber,
    this.year,
    this.duration,
    this.lyric,
    this.picture,
  });

  /// An empty set, for files with no readable tags.
  static const AudioTag empty = AudioTag();

  /// Song title.
  final String? title;

  /// Performing artist.
  final String? artist;

  /// Album name.
  final String? album;

  /// Track number within its album.
  final int? trackNumber;

  /// Release year.
  final int? year;

  /// Duration, when the container states it.
  final Duration? duration;

  /// Embedded lyric text, usually plain LRC or unsynchronised text.
  final String? lyric;

  /// Embedded cover art, when the reader was asked to include it.
  final AudioPicture? picture;

  /// Whether nothing at all was found.
  bool get isEmpty =>
      title == null &&
      artist == null &&
      album == null &&
      trackNumber == null &&
      year == null &&
      duration == null &&
      lyric == null &&
      picture == null;

  /// Fills this set's empty fields from [fallback].
  ///
  /// Used to layer containers: ID3v2 over ID3v1, for example.
  AudioTag orElse(AudioTag fallback) {
    return AudioTag(
      title: title ?? fallback.title,
      artist: artist ?? fallback.artist,
      album: album ?? fallback.album,
      trackNumber: trackNumber ?? fallback.trackNumber,
      year: year ?? fallback.year,
      duration: duration ?? fallback.duration,
      lyric: lyric ?? fallback.lyric,
      picture: picture ?? fallback.picture,
    );
  }

  @override
  String toString() =>
      'AudioTag(${title ?? '?'} / ${artist ?? '?'}, '
      '${duration == null ? 'duration unknown' : '${duration!.inSeconds}s'})';
}

/// One cover image embedded in a file.
@immutable
final class AudioPicture {
  /// Creates a picture.
  const AudioPicture({required this.bytes, required this.mimeType, this.description = ''});

  /// The encoded image (JPEG, PNG, …), exactly as stored.
  final Uint8List bytes;

  /// MIME type as the container reports it; empty when unknown.
  final String mimeType;

  /// The picture's description, for the pictures that carry one.
  final String description;

  /// Whether the picture has usable bytes.
  bool get isEmpty => bytes.isEmpty;

  @override
  String toString() => 'AudioPicture($mimeType, ${bytes.length} bytes)';
}
