import 'dart:convert';
import 'dart:io';

import 'package:media_core_audio/src/local/audio_tag.dart';
import 'package:media_core_audio/src/local/audio_tag_reader.dart';
import 'package:media_core_audio/src/source/music_source.dart';
import 'package:media_core_audio/src/track/music_quality.dart';
import 'package:media_core_audio/src/track/music_track.dart';
import 'package:media_core_audio/src/track/track_source.dart';

/// A [MusicSource] over the device's own files.
///
/// Local music is not a special case in the queue — it is just a source whose
/// resolution is a `file:` URI and whose "search" walks directories. Keeping
/// it in the same contract is what lets a playlist mix streamed and downloaded
/// tracks (lx-music's local library behaves the same way).
///
/// A scan reads each file's tags ([AudioTagReader]) so a local song is titled
/// by its tags rather than its file name, and an embedded lyric answers when
/// there is no sidecar `.lrc`.
final class LocalMusicSource extends MusicSource {
  /// Creates a local source over [roots].
  ///
  /// [extensions] is matched case-insensitively against the file suffix.
  LocalMusicSource({
    required this.roots,
    this.id = MusicTrack.localSourceId,
    this.name = '本地音乐',
    this.extensions = defaultExtensions,
    this.maxFilesPerScan = 5000,
    this.readTags = true,
    this.tagReader = const AudioTagReader(),
    this.tagReadConcurrency = 4,
  });

  /// Audio containers this source accepts, without the leading dot.
  static const List<String> defaultExtensions = <String>[
    'mp3',
    'flac',
    'm4a',
    'aac',
    'ogg',
    'opus',
    'wav',
    'ape',
    'wma',
    'dsf',
  ];

  @override
  final String id;

  @override
  final String name;

  /// Directories to scan.
  final List<String> roots;

  /// Accepted file suffixes.
  final List<String> extensions;

  /// Safety cap so a mis-pointed root cannot hang the app.
  final int maxFilesPerScan;

  /// Whether a scan reads each file's tags.
  ///
  /// A host that wants only file names turns this off and saves the reads; the
  /// tracks then carry the same titles they always did.
  final bool readTags;

  /// The tag reader; replaceable for hosts with a different parser.
  final AudioTagReader tagReader;

  /// How many files are read at once during a scan.
  ///
  /// Tags live at the head of a file, so this is disk-bound rather than
  /// memory-bound; a small window keeps a network share from being hammered
  /// while still finishing a library in one pass.
  final int tagReadConcurrency;

  final Map<String, _CachedTag> _tagCache = <String, _CachedTag>{};
  final Map<String, AudioPicture?> _coverCache = <String, AudioPicture?>{};

  /// Lists the audio files under [roots].
  ///
  /// Title, artist, album and duration come from the file's tags when it has
  /// them; the file name (without its extension) is the title otherwise.
  @override
  Future<MusicSourcePage<MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final all = await listTracks();
    final needle = keyword.trim().toLowerCase();

    final matched = needle.isEmpty
        ? all
        : all
              .where(
                (track) => track.title.toLowerCase().contains(needle) || track.artist.toLowerCase().contains(needle),
              )
              .toList(growable: false);

    final start = ((page - 1) * pageSize).clamp(0, matched.length);
    final end = (start + pageSize).clamp(0, matched.length);

    return MusicSourcePage<MusicTrack>(
      items: matched.sublist(start, end),
      page: page,
      hasMore: end < matched.length,
      total: matched.length,
    );
  }

  /// Scans [roots] for playable files.
  Future<List<MusicTrack>> listTracks() async {
    final paths = <String>[];

    for (final root in roots) {
      final directory = Directory(root);

      if (!directory.existsSync()) {
        continue;
      }

      try {
        await for (final entity in directory.list(recursive: true, followLinks: false)) {
          if (entity is! File || !_isAudio(entity.path)) {
            continue;
          }

          paths.add(entity.path);

          if (paths.length >= maxFilesPerScan) {
            break;
          }
        }
      } on FileSystemException {
        // An unreadable root contributes nothing; the rest of the library
        // still loads.
      }

      if (paths.length >= maxFilesPerScan) {
        break;
      }
    }

    final tracks = List<MusicTrack?>.filled(paths.length, null);
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final index = next++;

        if (index >= paths.length) {
          return;
        }

        tracks[index] = await _trackOf(paths[index]);
      }
    }

    final workers = <Future<void>>[
      for (var index = 0; index < tagReadConcurrency && index < paths.length; index++) worker(),
    ];

    await Future.wait(workers);

    final result = <MusicTrack>[for (final track in tracks) ?track];

    return result..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  /// Reads [track]'s tags, from the cache when the file has not changed.
  Future<AudioTag> tagOf(MusicTrack track) => _tagFor(track.localPath ?? track.id);

  /// Reads [track]'s embedded cover, or null when it has none.
  ///
  /// Kept apart from [listTracks] on purpose: cover bytes are the largest part
  /// of a tag, and a list does not draw them until the viewer asks.
  Future<AudioPicture?> coverOf(MusicTrack track) async {
    final path = track.localPath ?? track.id;

    if (_coverCache.containsKey(path)) {
      return _coverCache[path];
    }

    final picture = (await _tagFor(path, includePicture: true)).picture;

    if (_coverCache.length >= 64) {
      _coverCache.remove(_coverCache.keys.first);
    }

    _coverCache[path] = picture;

    return picture;
  }

  /// Resolves a local track to its file URI.
  @override
  Future<TrackSource> resolveTrackSource(MusicTrack track, {MusicQuality? quality}) async {
    final path = track.localPath ?? track.id;
    final file = File(path);

    if (!file.existsSync()) {
      throw StateError('Local track not found: $path');
    }

    return TrackSource(
      uri: file.uri,
      isLocal: true,
      quality: const MusicQuality(id: 'local', label: '本地', sort: 99),
      fileSize: file.lengthSync(),
    );
  }

  /// Reads a sidecar `.lrc` next to the audio file, then the embedded lyric.
  ///
  /// The sidecar wins because that is the file the viewer can edit; the tags
  /// answer only when no `.lrc` sits beside the song.
  ///
  /// The bytes are decoded with a BOM strip and a UTF-8 → Latin-1 fallback:
  /// lyric files in the wild are saved by many tools, and a single invalid
  /// byte used to make `readAsString` throw and hide an otherwise readable
  /// lyric. The fallback is not a GBK decoder — a host that needs correct GBK
  /// supplies its own `LyricProvider`.
  @override
  Future<MusicLyricPayload?> resolveLyric(MusicTrack track) async {
    final path = track.localPath ?? track.id;
    final dot = path.lastIndexOf('.');

    if (dot > 0) {
      final lyricFile = File('${path.substring(0, dot)}.lrc');

      if (lyricFile.existsSync()) {
        try {
          final bytes = await lyricFile.readAsBytes();

          return MusicLyricPayload(lyric: _decodeText(bytes));
        } on FileSystemException {
          // Fall through to the embedded lyric.
        }
      }
    }

    final embedded = (await _tagFor(path)).lyric;

    if (embedded == null || embedded.trim().isEmpty) {
      return null;
    }

    return MusicLyricPayload(lyric: embedded);
  }

  Future<MusicTrack> _trackOf(String path) async {
    final fileName = _titleOf(path);

    if (!readTags) {
      return MusicTrack.local(path: path, title: fileName);
    }

    final tag = await _tagFor(path);

    return MusicTrack(
      id: path,
      sourceId: id,
      localPath: path,
      title: _clean(tag.title) ?? fileName,
      artist: _clean(tag.artist) ?? '',
      album: _clean(tag.album) ?? '',
      duration: tag.duration,
      metadata: <String, Object?>{
        if (tag.trackNumber != null) 'trackNumber': tag.trackNumber,
        if (tag.year != null) 'year': tag.year,
      },
    );
  }

  Future<AudioTag> _tagFor(String path, {bool includePicture = false}) async {
    final file = File(path);

    try {
      final stat = file.statSync();
      final cached = _tagCache[path];

      if (cached != null && cached.modified == stat.modified && cached.size == stat.size) {
        // The cached entry has no picture; a caller that wants one reads the
        // file again rather than holding every cover of a library in memory.
        return includePicture ? await _readTag(file, includePicture: true) : cached.tag;
      }

      final tag = await _readTag(file, includePicture: includePicture);

      if (_tagCache.length >= 512) {
        _tagCache.remove(_tagCache.keys.first);
      }

      _tagCache[path] = _CachedTag(modified: stat.modified, size: stat.size, tag: tag);

      return tag;
    } on FileSystemException {
      return AudioTag.empty;
    }
  }

  Future<AudioTag> _readTag(File file, {required bool includePicture}) =>
      tagReader.read(file, includePicture: includePicture);

  String? _clean(String? value) {
    final trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _decodeText(List<int> bytes) {
    var start = 0;

    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      start = 3;
    }

    final body = start == 0 ? bytes : bytes.sublist(start);

    try {
      return const Utf8Decoder().convert(body);
    } on FormatException {
      return latin1.decode(body);
    }
  }

  bool _isAudio(String path) {
    final dot = path.lastIndexOf('.');

    if (dot <= 0 || dot == path.length - 1) {
      return false;
    }

    final suffix = path.substring(dot + 1).toLowerCase();

    return extensions.contains(suffix);
  }

  String _titleOf(String path) {
    final separator = path.lastIndexOf(RegExp(r'[\\/]'));
    final fileName = separator >= 0 ? path.substring(separator + 1) : path;
    final dot = fileName.lastIndexOf('.');

    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }
}

final class _CachedTag {
  const _CachedTag({required this.modified, required this.size, required this.tag});

  final DateTime modified;
  final int size;
  final AudioTag tag;
}
