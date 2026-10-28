import 'package:media_core_audio/src/lyric/lyric_exporter.dart';
import 'package:media_core_audio/src/source/music_source.dart'
    show MusicLyricPayload;
import 'package:media_core_audio/src/track/music_quality.dart';
import 'package:media_core_audio/src/track/music_track.dart';
import 'package:media_core_audio/src/track/track_source.dart';

/// Output container for a music download.
enum MusicDownloadFormat {
  /// Keep the source codec/container untouched (`-c:a copy`).
  ///
  /// The right choice whenever the source already is a finished file: it is
  /// lossless, instant, and avoids a re-encode of a lossy source.
  copy,

  /// MP3 (universally playable, small).
  mp3,

  /// AAC in MP4/M4A.
  m4a,

  /// FLAC (lossless).
  flac,

  /// Vorbis in Ogg.
  ogg,

  /// Uncompressed PCM.
  wav,
}

/// Everything one download needs.
///
/// The URL is a [TrackSource] at the moment the request is built, not a
/// resolved-at-run-time thing: music URLs expire, so the caller resolves and
/// hands over a URL that is valid *now* — and can rebuild the request from a
/// fresh resolution when the download is retried later.
///
/// The request also carries the post-processing choices separate from the
/// transfer itself (cover/lyric embedding, sidecar `.lrc`), because a direct
/// HTTP transfer and an ffmpeg transfer share them and only differ in how the
/// bytes arrive.
final class MusicDownloadRequest {
  /// Creates a request.
  const MusicDownloadRequest({
    required this.url,
    required this.outputPath,
    this.extension = 'm4a',
    this.headers = const <String, String>{},
    this.userAgent,
    this.format = MusicDownloadFormat.copy,
    this.bitrateKbps = 320,
    this.expectedDuration,
    this.title,
    this.artist,
    this.album,
    this.extraArguments = const <String>[],
    this.sourceId,
    this.trackId,
    this.qualityId,
    this.coverUrl,
    this.lyric,
    this.lyricTranslation,
    this.lyricRomanization,
    this.lyricFormat = 'lrc',
    this.embedCover = false,
    this.embedLyric = false,
    this.writeLyricFile = false,
    this.skipExisting = false,
    this.lyricEncoding = LyricFileEncoding.utf8Bom,
    this.includeTranslation = false,
    this.includeRomanization = false,
    this.includeWordTiming = false,
    this.includeAwlrc = false,
  });

  /// Builds a request for [track] resolved by [source].
  ///
  /// [directory] is the target folder; [pattern] names the file and may use
  /// `{title}`, `{artist}`, `{album}`, `{quality}`, `{source}`, `{list}` and
  /// `{index}`. The pattern is sanitized for the platform's file system —
  /// music titles contain `/`, `:` and `?` routinely. [subdirectory] adds an
  /// optional grouping folder (lx-music's "按列表名保存").
  factory MusicDownloadRequest.forTrack({
    required MusicTrack track,
    required TrackSource source,
    required String directory,
    String pattern = '{artist} - {title}',
    MusicDownloadFormat? format,
    int bitrateKbps = 320,
    MusicQuality? quality,
    String? listName,
    String? subdirectory,
    int? index,
    String? coverUrl,
    MusicLyricPayload? lyric,
    bool embedCover = false,
    bool embedLyric = false,
    bool writeLyricFile = false,
    bool skipExisting = false,
    LyricFileEncoding lyricEncoding = LyricFileEncoding.utf8Bom,
    bool includeTranslation = false,
    bool includeRomanization = false,
    bool includeWordTiming = false,
    bool includeAwlrc = false,
  }) {
    final plan = planFor(source, format: format, quality: quality);
    final separator = directory.endsWith('/') || directory.endsWith(r'\') ? '' : _separatorFor(directory);
    final folder = sanitizeSubdirectory(subdirectory);
    final folderPart = folder.isEmpty ? '' : '$folder${_separatorFor(directory)}';

    final name = sanitizeFileName(
      pattern
          .replaceAll('{title}', track.title)
          .replaceAll('{artist}', track.artist)
          .replaceAll('{album}', track.album)
          .replaceAll('{quality}', quality?.id ?? '')
          .replaceAll('{source}', track.sourceId)
          .replaceAll('{list}', listName ?? '')
          .replaceAll('{index}', index == null ? '' : index.toString().padLeft(2, '0')),
    );

    final fileName = _clip(name.isEmpty ? track.title : name, 120);

    return MusicDownloadRequest(
      url: source.uri.toString(),
      outputPath: '$directory$separator$folderPart${fileName.isEmpty ? track.id : fileName}.${plan.extension}',
      extension: plan.extension,
      headers: source.headers,
      format: plan.format,
      bitrateKbps: bitrateKbps,
      expectedDuration: source.duration ?? track.duration,
      title: track.title,
      artist: track.artist,
      album: track.album,
      sourceId: track.sourceId,
      trackId: track.id,
      qualityId: (quality ?? source.quality)?.id,
      coverUrl: coverUrl ?? track.coverUri?.toString(),
      lyric: lyric?.lyric,
      lyricTranslation: lyric?.translation,
      lyricRomanization: lyric?.romanization,
      lyricFormat: lyric?.format ?? 'lrc',
      embedCover: embedCover,
      embedLyric: embedLyric,
      writeLyricFile: writeLyricFile,
      skipExisting: skipExisting,
      lyricEncoding: lyricEncoding,
      includeTranslation: includeTranslation,
      includeRomanization: includeRomanization,
      includeWordTiming: includeWordTiming,
      includeAwlrc: includeAwlrc,
    );
  }

  /// Rebuilds a request from [toJson].
  factory MusicDownloadRequest.fromJson(Map<String, Object?> json) {
    final format = MusicDownloadFormat.values
        .where((value) => value.name == json['format'])
        .firstOrNull ?? MusicDownloadFormat.copy;
    final encoding = LyricFileEncoding.values
        .where((value) => value.name == json['lyricEncoding'])
        .firstOrNull ?? LyricFileEncoding.utf8Bom;
    final expectedDurationMs = json['expectedDurationMs'];

    return MusicDownloadRequest(
      url: json['url'] as String? ?? '',
      outputPath: json['outputPath'] as String? ?? '',
      extension: json['extension'] as String? ?? 'm4a',
      headers: <String, String>{
        for (final entry in (json['headers'] as Map<Object?, Object?>? ?? const <Object?, Object?>{}).entries)
          entry.key.toString(): entry.value.toString(),
      },
      userAgent: json['userAgent'] as String?,
      format: format,
      bitrateKbps: (json['bitrateKbps'] as num?)?.toInt() ?? 320,
      expectedDuration: expectedDurationMs is num ? Duration(milliseconds: expectedDurationMs.toInt()) : null,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      extraArguments: <String>[
        for (final value in json['extraArguments'] as List<Object?>? ?? const <Object?>[]) value.toString(),
      ],
      sourceId: json['sourceId'] as String?,
      trackId: json['trackId'] as String?,
      qualityId: json['qualityId'] as String?,
      coverUrl: json['coverUrl'] as String?,
      lyric: json['lyric'] as String?,
      lyricTranslation: json['lyricTranslation'] as String?,
      lyricRomanization: json['lyricRomanization'] as String?,
      lyricFormat: json['lyricFormat'] as String? ?? 'lrc',
      embedCover: json['embedCover'] == true,
      embedLyric: json['embedLyric'] == true,
      writeLyricFile: json['writeLyricFile'] == true,
      skipExisting: json['skipExisting'] == true,
      lyricEncoding: encoding,
      includeTranslation: json['includeTranslation'] == true,
      includeRomanization: json['includeRomanization'] == true,
      includeWordTiming: json['includeWordTiming'] == true,
      includeAwlrc: json['includeAwlrc'] == true,
    );
  }

  /// Source URL.
  final String url;

  /// Absolute output path, including the extension.
  final String outputPath;

  /// Output extension without the dot.
  final String extension;

  /// Request headers (referer, cookie, …).
  final Map<String, String> headers;

  /// User agent, when the source requires one.
  final String? userAgent;

  /// Output container.
  final MusicDownloadFormat format;

  /// Target bitrate for the transcoding formats.
  final int bitrateKbps;

  /// Expected duration, used to turn ffmpeg's progress into a percentage.
  final Duration? expectedDuration;

  /// Track title, written into the file's tags.
  final String? title;

  /// Track artist, written into the file's tags.
  final String? artist;

  /// Album, written into the file's tags.
  final String? album;

  /// Extra ffmpeg arguments appended before the output path.
  final List<String> extraArguments;

  /// Source that produced the track, for duplicate detection.
  final String? sourceId;

  /// Track id, for duplicate detection.
  final String? trackId;

  /// Quality tier requested for this download.
  final String? qualityId;

  /// Cover art URL, embedded or saved when the matching flag is on.
  final String? coverUrl;

  /// Original lyric text (LRC or decoded QRC/KRC/YRC).
  final String? lyric;

  /// Translation track.
  final String? lyricTranslation;

  /// Romanization track.
  final String? lyricRomanization;

  /// Format hint of [lyric].
  final String lyricFormat;

  /// Whether [coverUrl] is attached to the file's tag.
  final bool embedCover;

  /// Whether [lyric] is written into the file's tag.
  final bool embedLyric;

  /// Whether a sidecar `.lrc` is written next to the audio file.
  final bool writeLyricFile;

  /// Whether an existing output file short-circuits the download.
  final bool skipExisting;

  /// Encoding of the sidecar lyric file.
  final LyricFileEncoding lyricEncoding;

  /// Whether the sidecar lyric includes the translation track.
  final bool includeTranslation;

  /// Whether the sidecar lyric includes the romanization track.
  final bool includeRomanization;

  /// Whether the sidecar lyric includes word timing.
  final bool includeWordTiming;

  /// Whether the sidecar lyric includes the `[awlrc:…]` container.
  final bool includeAwlrc;

  /// Whether this is a stream copy.
  bool get isCopy => format == MusicDownloadFormat.copy;

  /// Whether bytes can be fetched directly over HTTP and appended to a file.
  ///
  /// A copy of a finished container is a byte-for-byte transfer, which is what
  /// makes pause/resume possible. HLS/DASH playlists and segmented streams are
  /// not files, so they keep the ffmpeg path even when the caller asked for
  /// [MusicDownloadFormat.copy].
  bool get isDirectTransfer {
    final uri = Uri.tryParse(url);

    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }

    return isCopy && copyableExtensions.contains(extension) && !streamingExtensions.contains(extension);
  }

  /// Sidecar lyric path (`…​.lrc`), or null when no sidecar is requested.
  String? get lyricPath {
    if (!writeLyricFile) {
      return null;
    }

    final dot = outputPath.lastIndexOf('.');

    return '${dot <= 0 ? outputPath : outputPath.substring(0, dot)}.lrc';
  }

  /// Key that identifies "the same download" for duplicate filtering.
  ///
  /// The quality is part of the key on purpose: downloading the same song at
  /// 320k and FLAC are two files, while pressing download twice at the same
  /// tier is one task (lx-music's rule).
  String get dedupeKey => <String>[
    sourceId ?? '',
    trackId ?? url,
    qualityId ?? '',
    extension,
  ].join('\u0000');

  /// File extension of [format].
  static String extensionFor(MusicDownloadFormat format) {
    return switch (format) {
      MusicDownloadFormat.copy => 'm4a',
      MusicDownloadFormat.mp3 => 'mp3',
      MusicDownloadFormat.m4a => 'm4a',
      MusicDownloadFormat.flac => 'flac',
      MusicDownloadFormat.ogg => 'ogg',
      MusicDownloadFormat.wav => 'wav',
    };
  }

  /// Decides how a resolved source should be saved.
  ///
  /// Copying is preferred — the platform already encoded the audio once and a
  /// re-encode only loses quality — but a copy is only sound when the source
  /// already *is* a file in a container we can name. A stream URL (`m3u8`,
  /// `ts`, `m4s`, `flv`) is a byte stream whose codec cannot be inferred from
  /// the URL, and writing those bytes into `.m4a` produces a file that does
  /// not play: those are transcoded instead.
  ///
  /// When transcoding, [quality]'s `formatHint` picks the output container so
  /// a FLAC request does not silently become MP3.
  static ({MusicDownloadFormat format, String extension}) planFor(
    TrackSource source, {
    MusicDownloadFormat? format,
    MusicQuality? quality,
  }) {
    final sourceExtension = _extensionOf(source.uri);
    final copyable = sourceExtension != null && copyableExtensions.contains(sourceExtension);

    if (format != null && format != MusicDownloadFormat.copy) {
      return (format: format, extension: extensionFor(format));
    }

    if (copyable) {
      return (format: MusicDownloadFormat.copy, extension: sourceExtension);
    }

    final hinted = _formatFromHint(quality?.formatHint);

    return (format: hinted, extension: extensionFor(hinted));
  }

  /// Removes characters a file name cannot contain or that confuse tooling.
  static String sanitizeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();

    // Trailing dots and spaces are rejected by Windows.
    final trimmed = cleaned.replaceAll(RegExp(r'[. ]+$'), '');

    return trimmed.length <= 120 ? trimmed : trimmed.substring(0, 120).trim();
  }

  /// Sanitizes a grouping folder, dropping empty and parent segments.
  ///
  /// A list name is user input; letting `..` through would put the file
  /// outside the download directory the viewer chose.
  static String sanitizeSubdirectory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    final segments = value
        .split(RegExp(r'[\\/]+'))
        .map(sanitizeFileName)
        .where((segment) => segment.isNotEmpty && segment != '.' && segment != '..')
        .toList(growable: false);

    return segments.join('/');
  }

  /// Serializes the request for host-side persistence.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'url': url,
      'outputPath': outputPath,
      'extension': extension,
      'headers': headers,
      'userAgent': userAgent,
      'format': format.name,
      'bitrateKbps': bitrateKbps,
      'expectedDurationMs': expectedDuration?.inMilliseconds,
      'title': title,
      'artist': artist,
      'album': album,
      'extraArguments': extraArguments,
      'sourceId': sourceId,
      'trackId': trackId,
      'qualityId': qualityId,
      'coverUrl': coverUrl,
      'lyric': lyric,
      'lyricTranslation': lyricTranslation,
      'lyricRomanization': lyricRomanization,
      'lyricFormat': lyricFormat,
      'embedCover': embedCover,
      'embedLyric': embedLyric,
      'writeLyricFile': writeLyricFile,
      'skipExisting': skipExisting,
      'lyricEncoding': lyricEncoding.name,
      'includeTranslation': includeTranslation,
      'includeRomanization': includeRomanization,
      'includeWordTiming': includeWordTiming,
      'includeAwlrc': includeAwlrc,
    }..removeWhere((key, value) => value == null);
  }

  /// Extensions whose bytes can be copied verbatim into the same container.
  static const Set<String> copyableExtensions = <String>{
    'mp3',
    'm4a',
    'mp4',
    'aac',
    'flac',
    'ogg',
    'opus',
    'wav',
    'ape',
    'wma',
  };

  /// Extensions that are byte streams rather than finished files.
  static const Set<String> streamingExtensions = <String>{
    'm3u8',
    'm3u',
    'ts',
    'm4s',
    'mpd',
    'flv',
  };

  static MusicDownloadFormat _formatFromHint(String? hint) {
    return switch (hint?.trim().toLowerCase()) {
      'flac' => MusicDownloadFormat.flac,
      'wav' => MusicDownloadFormat.wav,
      'm4a' => MusicDownloadFormat.m4a,
      'ogg' => MusicDownloadFormat.ogg,
      _ => MusicDownloadFormat.mp3,
    };
  }

  static String? _extensionOf(Uri uri) {
    final segments = uri.pathSegments;

    if (segments.isEmpty) {
      return null;
    }

    final dot = segments.last.lastIndexOf('.');

    return dot > 0 ? segments.last.substring(dot + 1).toLowerCase() : null;
  }

  static String _clip(String value, int maxLength) {
    return value.length <= maxLength ? value : value.substring(0, maxLength).trim();
  }

  static String _separatorFor(String directory) => directory.contains(r'\') ? r'\' : '/';

  @override
  String toString() => 'MusicDownloadRequest($url -> $outputPath, ${format.name})';
}
