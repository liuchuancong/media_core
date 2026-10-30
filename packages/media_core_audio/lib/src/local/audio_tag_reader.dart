import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:media_core_audio/src/local/audio_tag.dart';

/// Reads the tags of local audio files without decoding their audio.
///
/// Covers the containers a music library actually holds: ID3v1/ID3v2 on MP3,
/// FLAC's Vorbis comments and picture blocks, MP4/M4A's `ilst`, Ogg Vorbis and
/// Opus comments, and WAV's `LIST/INFO`. Anything else answers [AudioTag.empty]
/// instead of throwing, because an untagged file is a normal file.
///
/// The reader is pure Dart and only touches the bytes a tag needs: the head of
/// the file, the metadata blocks, and — for MP3 — the frame header plus the
/// trailing ID3v1. That keeps a scan over thousands of files cheap.
final class AudioTagReader {
  /// Creates a reader.
  const AudioTagReader({this.maxMetadataBytes = 16 * 1024 * 1024, this.maxPictureBytes = 24 * 1024 * 1024});

  /// Cap on one metadata block, so a corrupt length cannot allocate a file's
  /// whole size. A cover lives in its own block and uses [maxPictureBytes].
  final int maxMetadataBytes;

  /// Cap on an embedded cover, for the same reason.
  final int maxPictureBytes;

  /// Reads [file]'s tags.
  ///
  /// [includePicture] is false during a library scan: covers are the largest
  /// thing a tag holds, and a list does not draw them until asked.
  Future<AudioTag> read(File file, {bool includePicture = true}) async {
    RandomAccessFile? handle;

    try {
      handle = await file.open();

      final source = _FileSource(handle, await handle.length());

      return await _parse(source, _extensionOf(file.path), includePicture);
    } on Object {
      // A missing, locked or unreadable file has no tags to report.
      return AudioTag.empty;
    } finally {
      await handle?.close();
    }
  }

  /// Reads tags from bytes already in memory.
  ///
  /// [extension] selects the container when the bytes' own signature cannot;
  /// the signature wins when it can, so an `.mp3` that is really a FLAC still
  /// parses. Useful for tests and for hosts that keep a file's head in memory.
  Future<AudioTag> parse(Uint8List bytes, {required String extension, bool includePicture = true}) {
    return _parse(_MemorySource(bytes), extension.toLowerCase(), includePicture);
  }

  Future<AudioTag> _parse(_Source source, String extension, bool includePicture) async {
    final head = await source.read(0, 12);

    if (_ascii(head, 0, 3) == 'ID3') {
      return await _readMp3(source, includePicture);
    }

    if (_ascii(head, 0, 4) == 'fLaC') {
      return await _readFlac(source, includePicture);
    }

    if (_ascii(head, 0, 4) == 'OggS') {
      return await _readOgg(source);
    }

    if (_ascii(head, 0, 4) == 'RIFF' && _ascii(head, 8, 4) == 'WAVE') {
      return await _readWav(source);
    }

    if (_ascii(head, 4, 4) == 'ftyp') {
      return await _readMp4(source, includePicture);
    }

    return switch (extension) {
      'mp3' => await _readMp3(source, includePicture),
      'flac' => await _readFlac(source, includePicture),
      'm4a' || 'mp4' || 'm4b' => await _readMp4(source, includePicture),
      'ogg' || 'opus' || 'oga' => await _readOgg(source),
      'wav' => await _readWav(source),
      _ => AudioTag.empty,
    };
  }

  // ---------------------------------------------------------------------------
  // MP3 / ID3
  // ---------------------------------------------------------------------------

  Future<AudioTag> _readMp3(_Source source, bool includePicture) async {
    var audioStart = 0;
    var tag = AudioTag.empty;
    final head = await source.read(0, 10);

    if (_ascii(head, 0, 3) == 'ID3' && head.length >= 10) {
      final major = head[3];
      final flags = head[5];
      final size = _synchsafe32(head, 6);

      if (size > 0 && size <= maxMetadataBytes) {
        final body = await source.read(10, size);

        tag = _parseId3v2(body, major: major, flags: flags, includePicture: includePicture);
      }

      // The tag size counts the extended header and, in v2.4, the footer.
      audioStart = 10 + size;
    }

    if (source.length >= 128) {
      final tail = await source.read(source.length - 128, 128);

      if (_ascii(tail, 0, 3) == 'TAG') {
        tag = tag.orElse(_parseId3v1(tail));
      }
    }

    final duration = await _mp3Duration(source, audioStart);

    return tag.orElse(AudioTag(duration: duration));
  }

  AudioTag _parseId3v2(Uint8List body, {required int major, required int flags, required bool includePicture}) {
    // Header-level unsynchronisation makes every 0xFF 0x00 pair stand for one
    // 0xFF byte, including inside frame payloads.
    final data = flags & 0x80 == 0 ? body : _deunsynchronise(body);
    var offset = 0;

    if (flags & 0x40 != 0 && data.length >= 4) {
      // Extended header: v2.3's size excludes its own four bytes, v2.4's is
      // synchsafe and includes them.
      final extended = major >= 4 ? _synchsafe32(data, 0) : _be32(data, 0) + 4;

      offset = extended.clamp(0, data.length);
    }

    var tag = AudioTag.empty;
    var guard = 0;

    while (offset + 6 <= data.length && guard++ < 512) {
      final idLength = major == 2 ? 3 : 4;
      final frameId = _ascii(data, offset, idLength);

      if (frameId.isEmpty || frameId.codeUnitAt(0) == 0) {
        break;
      }

      final int size;
      final int header;

      if (major == 2) {
        size = (data[offset + 3] << 16) | (data[offset + 4] << 8) | data[offset + 5];
        header = 6;
      } else {
        size = major >= 4 ? _synchsafe32(data, offset + 4) : _be32(data, offset + 4);
        header = 10;
      }

      if (size <= 0 || offset + header + size > data.length) {
        break;
      }

      final payload = Uint8List.sublistView(data, offset + header, offset + header + size);

      tag = tag.orElse(_parseId3Frame(frameId, payload, includePicture: includePicture));
      offset += header + size;
    }

    return tag;
  }

  AudioTag _parseId3Frame(String id, Uint8List payload, {required bool includePicture}) {
    switch (id) {
      case 'TIT2' || 'TT2':
        return AudioTag(title: _id3Text(payload));
      case 'TPE1' || 'TP1':
        return AudioTag(artist: _id3Text(payload));
      case 'TALB' || 'TAL':
        return AudioTag(album: _id3Text(payload));
      case 'TRCK' || 'TRK':
        final value = _id3Text(payload);

        return AudioTag(trackNumber: int.tryParse(RegExp(r'^\d+').stringMatch(value ?? '') ?? ''));
      case 'TYER' || 'TYE' || 'TDRC':
        final value = _id3Text(payload);

        return AudioTag(year: int.tryParse(RegExp(r'^\d{4}').stringMatch(value ?? '') ?? ''));
      case 'USLT' || 'ULT':
        return AudioTag(lyric: _id3UnsynchronisedLyric(payload));
      case 'SYLT' || 'SLT':
        return AudioTag(lyric: _id3SynchronisedLyric(payload));
      case 'APIC' || 'PIC':
        return includePicture ? AudioTag(picture: _id3Picture(payload, version2: id == 'PIC')) : AudioTag.empty;
      default:
        return AudioTag.empty;
    }
  }

  String? _id3Text(Uint8List payload) {
    if (payload.isEmpty) {
      return null;
    }

    final text = _decodeId3Text(payload[0], Uint8List.sublistView(payload, 1)).replaceAll('\u0000', '').trim();

    return text.isEmpty ? null : text;
  }

  String? _id3UnsynchronisedLyric(Uint8List payload) {
    if (payload.length < 5) {
      return null;
    }

    final encoding = payload[0];
    var offset = 4; // encoding + three-byte language

    offset = _encodedStringEnd(payload, offset, encoding);

    if (offset >= payload.length) {
      return null;
    }

    final text = _decodeId3Text(encoding, Uint8List.sublistView(payload, offset)).trim();

    return text.isEmpty ? null : text;
  }

  String? _id3SynchronisedLyric(Uint8List payload) {
    if (payload.length < 7) {
      return null;
    }

    final encoding = payload[0];
    final timestampFormat = payload[4];

    var offset = _encodedStringEnd(payload, 6, encoding); // language + content type + description
    final lines = <String>[];

    while (offset < payload.length) {
      final textEnd = _encodedStringEnd(payload, offset, encoding);

      if (textEnd > payload.length) {
        break;
      }

      final terminator = encoding == 1 || encoding == 2 ? 2 : 1;
      final text = _decodeId3Text(
        encoding,
        Uint8List.sublistView(payload, offset, (textEnd - terminator).clamp(offset, textEnd)),
      ).trim();
      offset = textEnd;

      if (offset + 4 > payload.length) {
        break;
      }

      final stamp = _be32(payload, offset);
      offset += 4;

      if (text.isEmpty) {
        continue;
      }

      if (timestampFormat == 2) {
        final minutes = stamp ~/ 60000;
        final seconds = (stamp % 60000) / 1000;

        lines.add('[${minutes.toString().padLeft(2, '0')}:${seconds.toStringAsFixed(2).padLeft(5, '0')}]$text');
      } else {
        lines.add(text);
      }
    }

    return lines.isEmpty ? null : lines.join('\n');
  }

  AudioPicture? _id3Picture(Uint8List payload, {required bool version2}) {
    if (payload.length < 6) {
      return null;
    }

    final encoding = payload[0];
    var offset = 1;

    String mime;

    if (version2) {
      mime = _pictureMime(_ascii(payload, 1, 3));
      offset = 4;
    } else {
      final mimeTerminator = payload.indexOf(0, offset);
      final mimeEnd = mimeTerminator < 0 ? payload.length : mimeTerminator;

      mime = _ascii(payload, offset, mimeEnd - offset).toLowerCase();
      offset = mimeEnd + 1;
    }

    offset += 1; // picture type

    if (offset >= payload.length) {
      return null;
    }

    offset = _encodedStringEnd(payload, offset, encoding);

    if (offset >= payload.length) {
      return null;
    }

    final bytes = Uint8List.sublistView(payload, offset);

    if (bytes.isEmpty) {
      return null;
    }

    return AudioPicture(bytes: bytes, mimeType: mime.isEmpty ? _guessMime(bytes) : mime);
  }

  AudioTag _parseId3v1(Uint8List tail) {
    String field(int start, int length) => _ascii(tail, start, length).replaceAll('\u0000', ' ').trim();
    // ID3v1.1 borrows the last comment byte for the track number.
    final hasTrack = tail[125] == 0 && tail[126] != 0;

    return AudioTag(
      title: _nullIfEmpty(field(3, 30)),
      artist: _nullIfEmpty(field(33, 30)),
      album: _nullIfEmpty(field(63, 30)),
      year: int.tryParse(field(93, 4)),
      trackNumber: hasTrack ? tail[126] : null,
    );
  }

  Future<Duration?> _mp3Duration(_Source source, int audioStart) async {
    if (audioStart >= source.length) {
      return null;
    }

    final probe = await source.read(audioStart, 128 * 1024);
    var offset = 0;

    while (offset + 4 <= probe.length) {
      if (probe[offset] == 0xFF && probe[offset + 1] & 0xE0 == 0xE0) {
        final header = _Mp3FrameHeader.parse(probe, offset);

        if (header != null) {
          final xingOffset = offset + 4 + header.sideInfoLength;

          if (xingOffset + 12 <= probe.length) {
            final marker = _ascii(probe, xingOffset, 4);

            if (marker == 'Xing' || marker == 'Info') {
              final flags = _be32(probe, xingOffset + 4);
              final frames = flags & 1 == 0 ? 0 : _be32(probe, xingOffset + 8);

              if (frames > 0) {
                return Duration(microseconds: (frames * header.samplesPerFrame * 1000000 / header.sampleRate).round());
              }
            }
          }

          final audioBytes = source.length - (audioStart + offset);

          if (audioBytes > 0 && header.bitrate > 0) {
            return Duration(microseconds: (audioBytes * 8 * 1000000 / (header.bitrate * 1000)).round());
          }
        }
      }

      offset++;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // FLAC
  // ---------------------------------------------------------------------------

  Future<AudioTag> _readFlac(_Source source, bool includePicture) async {
    if (_ascii(await source.read(0, 4), 0, 4) != 'fLaC') {
      return AudioTag.empty;
    }

    var offset = 4;
    var tag = AudioTag.empty;
    Duration? duration;
    var guard = 0;

    while (offset + 4 <= source.length && guard++ < 256) {
      final block = await source.read(offset, 4);

      if (block.length < 4) {
        break;
      }

      final last = block[0] & 0x80 != 0;
      final type = block[0] & 0x7F;
      final size = (block[1] << 16) | (block[2] << 8) | block[3];
      final payloadStart = offset + 4;

      if (size < 0 || payloadStart + size > source.length) {
        break;
      }

      if (type == 0 && size >= 18) {
        duration = _flacDuration(await source.read(payloadStart, min(size, 34)));
      } else if (type == 4 && size <= maxMetadataBytes) {
        tag = tag.orElse(_parseVorbisComment(await source.read(payloadStart, size)));
      } else if (type == 6 && includePicture && size <= maxPictureBytes) {
        final picture = _parseFlacPicture(await source.read(payloadStart, size));

        if (picture != null) {
          tag = tag.orElse(AudioTag(picture: picture));
        }
      }

      offset = payloadStart + size;

      if (last) {
        break;
      }
    }

    return tag.orElse(AudioTag(duration: duration));
  }

  Duration? _flacDuration(Uint8List streamInfo) {
    if (streamInfo.length < 18) {
      return null;
    }

    var packed = 0;

    for (var index = 10; index < 18; index++) {
      packed = (packed << 8) | streamInfo[index];
    }

    final sampleRate = (packed >> 44) & 0xFFFFF;
    final totalSamples = packed & 0xFFFFFFFFF;

    if (sampleRate <= 0 || totalSamples <= 0) {
      return null;
    }

    return Duration(microseconds: (totalSamples * 1000000 / sampleRate).round());
  }

  AudioTag _parseVorbisComment(Uint8List data) {
    var offset = 0;

    if (offset + 4 > data.length) {
      return AudioTag.empty;
    }

    final vendorLength = _le32(data, offset);
    offset += 4 + vendorLength;

    if (offset + 4 > data.length) {
      return AudioTag.empty;
    }

    final count = _le32(data, offset);
    offset += 4;

    final fields = <String, String>{};

    for (var index = 0; index < count && offset + 4 <= data.length; index++) {
      final length = _le32(data, offset);
      offset += 4;

      if (length <= 0 || offset + length > data.length) {
        break;
      }

      final entry = utf8.decode(Uint8List.sublistView(data, offset, offset + length), allowMalformed: true);
      offset += length;

      final equals = entry.indexOf('=');

      if (equals <= 0) {
        continue;
      }

      final key = entry.substring(0, equals).toUpperCase();
      final value = entry.substring(equals + 1).trim();

      if (value.isNotEmpty && !fields.containsKey(key)) {
        fields[key] = value;
      }
    }

    final artist = fields['ARTIST'] ?? fields['ALBUMARTIST'];
    final date = fields['DATE'] ?? fields['YEAR'];

    return AudioTag(
      title: fields['TITLE'],
      artist: artist,
      album: fields['ALBUM'],
      trackNumber: int.tryParse(RegExp(r'^\d+').stringMatch(fields['TRACKNUMBER'] ?? '') ?? ''),
      year: int.tryParse(RegExp(r'^\d{4}').stringMatch(date ?? '') ?? ''),
      lyric: fields['LYRICS'] ?? fields['UNSYNCEDLYRICS'],
    );
  }

  AudioPicture? _parseFlacPicture(Uint8List data) {
    var offset = 0;

    int takeLength() {
      if (offset + 4 > data.length) {
        return -1;
      }

      final length = _be32(data, offset);
      offset += 4;

      return length;
    }

    if (takeLength() < 0) {
      return null;
    }

    final mimeLength = takeLength();

    if (mimeLength < 0 || offset + mimeLength > data.length) {
      return null;
    }

    final mime = _ascii(data, offset, mimeLength);
    offset += mimeLength;

    // The mime string comes before the description length — the spec reads
    // type, mime length, mime, then description length.
    final descriptionLength = takeLength();

    if (descriptionLength < 0 || offset + descriptionLength + 16 > data.length) {
      return null;
    }

    final description = utf8.decode(
      Uint8List.sublistView(data, offset, offset + descriptionLength),
      allowMalformed: true,
    );
    offset += descriptionLength + 16; // width, height, depth, colours

    final dataLength = takeLength();

    if (dataLength <= 0 || offset + dataLength > data.length) {
      return null;
    }

    final bytes = Uint8List.sublistView(data, offset, offset + dataLength);

    return AudioPicture(bytes: bytes, mimeType: mime.isEmpty ? _guessMime(bytes) : mime, description: description);
  }

  // ---------------------------------------------------------------------------
  // MP4 / M4A
  // ---------------------------------------------------------------------------

  Future<AudioTag> _readMp4(_Source source, bool includePicture) async {
    var offset = 0;
    var guard = 0;

    while (offset + 8 <= source.length && guard++ < 1024) {
      final header = await source.read(offset, 16);
      var size = _be32(header, 0);
      final type = _ascii(header, 4, 4);
      var headerLength = 8;

      if (size == 1) {
        size = _be64(header, 8);
        headerLength = 16;
      } else if (size == 0) {
        size = source.length - offset;
      }

      if (size < headerLength || offset + size > source.length) {
        break;
      }

      if (type == 'moov') {
        if (size - headerLength > maxMetadataBytes + maxPictureBytes) {
          return AudioTag.empty;
        }

        final moov = await source.read(offset + headerLength, size - headerLength);

        return _parseMoov(moov, includePicture);
      }

      offset += size;
    }

    return AudioTag.empty;
  }

  AudioTag _parseMoov(Uint8List moov, bool includePicture) {
    Duration? duration;
    final mvhd = _findAtom(moov, 0, moov.length, 'mvhd');

    if (mvhd != null) {
      duration = _mp4Duration(moov, mvhd.$1, mvhd.$2);
    }

    var tag = AudioTag.empty;
    final udta = _findAtom(moov, 0, moov.length, 'udta');

    if (udta != null) {
      final meta = _findAtom(moov, udta.$1, udta.$2, 'meta');

      if (meta != null) {
        final ilst = _findAtom(moov, meta.$1 + 4, meta.$2, 'ilst');

        if (ilst != null) {
          tag = _parseIlst(moov, ilst.$1, ilst.$2, includePicture);
        }
      }
    }

    return tag.orElse(AudioTag(duration: duration));
  }

  Duration? _mp4Duration(Uint8List data, int start, int end) {
    if (end - start < 20) {
      return null;
    }

    final version = data[start];

    if (version == 1) {
      if (end - start < 32) {
        return null;
      }

      final timescale = _be32(data, start + 20);
      final units = _be64(data, start + 24);

      if (timescale <= 0 || units <= 0) {
        return null;
      }

      return Duration(microseconds: (units * 1000000 / timescale).round());
    }

    final timescale = _be32(data, start + 12);
    final units = _be32(data, start + 16);

    if (timescale <= 0 || units <= 0) {
      return null;
    }

    return Duration(microseconds: (units * 1000000 / timescale).round());
  }

  AudioTag _parseIlst(Uint8List data, int start, int end, bool includePicture) {
    var tag = AudioTag.empty;
    var offset = start;

    while (offset + 8 <= end) {
      var size = _be32(data, offset);
      final type = _ascii(data, offset + 4, 4);
      var header = 8;

      if (size == 1) {
        if (offset + 16 > end) {
          break;
        }

        size = _be64(data, offset + 8);
        header = 16;
      }

      if (size < header || offset + size > end) {
        break;
      }

      final payloadStart = offset + header;
      final payloadEnd = offset + size;
      final value = _dataValue(data, payloadStart, payloadEnd);

      if (value != null) {
        final text = value.$2;
        final bytes = value.$3;

        switch (type) {
          case '©nam':
            tag = tag.orElse(AudioTag(title: _nullIfEmpty(text)));
          case '©ART':
            tag = tag.orElse(AudioTag(artist: _nullIfEmpty(text)));
          case 'aART':
            tag = tag.orElse(AudioTag(artist: _nullIfEmpty(text)));
          case '©alb':
            tag = tag.orElse(AudioTag(album: _nullIfEmpty(text)));
          case '©day':
            tag = tag.orElse(AudioTag(year: int.tryParse(RegExp(r'^\d{4}').stringMatch(text ?? '') ?? '')));
          case '©lyr':
            tag = tag.orElse(AudioTag(lyric: _nullIfEmpty(text)));
          case 'trkn':
            if (bytes != null && bytes.length >= 4) {
              tag = tag.orElse(AudioTag(trackNumber: _be16(bytes, 2)));
            }
          case 'covr':
            if (includePicture && bytes != null && bytes.isNotEmpty) {
              tag = tag.orElse(
                AudioTag(
                  picture: AudioPicture(bytes: bytes, mimeType: _guessMime(bytes)),
                ),
              );
            }
        }
      }

      offset = payloadEnd;
    }

    return tag;
  }

  /// The first `data` child of an `ilst` item: its text and raw bytes.
  (int, String?, Uint8List?)? _dataValue(Uint8List data, int start, int end) {
    var offset = start;

    while (offset + 8 <= end) {
      var size = _be32(data, offset);
      final type = _ascii(data, offset + 4, 4);
      var header = 8;

      if (size == 1) {
        if (offset + 16 > end) {
          return null;
        }

        size = _be64(data, offset + 8);
        header = 16;
      }

      if (size < header || offset + size > end) {
        return null;
      }

      if (type == 'data') {
        final payloadStart = offset + header;
        final payloadEnd = offset + size;

        if (payloadEnd - payloadStart < 8) {
          return null;
        }

        final kind = _be32(data, payloadStart) & 0xFFFFFF;
        final bytes = Uint8List.sublistView(data, payloadStart + 8, payloadEnd);
        final text = switch (kind) {
          1 => utf8.decode(bytes, allowMalformed: true),
          2 => _decodeUtf16(bytes, littleEndian: false),
          _ => null,
        };

        return (kind, text, bytes);
      }

      offset += size;
    }

    return null;
  }

  (int, int)? _findAtom(Uint8List data, int start, int end, String wanted) {
    var offset = start;

    while (offset + 8 <= end) {
      var size = _be32(data, offset);
      final type = _ascii(data, offset + 4, 4);
      var header = 8;

      if (size == 1) {
        if (offset + 16 > end) {
          return null;
        }

        size = _be64(data, offset + 8);
        header = 16;
      } else if (size == 0) {
        size = end - offset;
      }

      if (size < header || offset + size > end) {
        return null;
      }

      if (type == wanted) {
        return (offset + header, offset + size);
      }

      offset += size;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Ogg Vorbis / Opus
  // ---------------------------------------------------------------------------

  Future<AudioTag> _readOgg(_Source source) async {
    final head = await source.read(0, min(source.length, 256 * 1024));
    final packets = _oggPackets(head);

    for (final packet in packets.take(6)) {
      if (_ascii(packet, 0, 7) == '\u0003vorbis') {
        return _parseVorbisComment(Uint8List.sublistView(packet, 7));
      }

      if (_ascii(packet, 0, 8) == 'OpusTags') {
        return _parseVorbisComment(Uint8List.sublistView(packet, 8));
      }
    }

    return AudioTag.empty;
  }

  List<Uint8List> _oggPackets(Uint8List data) {
    final packets = <Uint8List>[];
    var offset = 0;
    final pending = BytesBuilder(copy: false);
    var guard = 0;

    while (offset + 27 <= data.length && guard++ < 64 && _ascii(data, offset, 4) == 'OggS') {
      final segments = data[offset + 26];

      if (offset + 27 + segments > data.length) {
        break;
      }

      final tableStart = offset + 27;
      var cursor = tableStart + segments;
      var complete = false;

      for (var index = 0; index < segments; index++) {
        final lace = data[tableStart + index];
        final take = min(lace, data.length - cursor);

        if (take > 0) {
          pending.add(Uint8List.sublistView(data, cursor, cursor + take));
        }

        cursor += take;

        if (lace < 255) {
          complete = true;
        }
      }

      offset = cursor;

      if (complete) {
        packets.add(pending.takeBytes());

        if (packets.length > 8) {
          break;
        }
      }
    }

    return packets;
  }

  // ---------------------------------------------------------------------------
  // WAV
  // ---------------------------------------------------------------------------

  Future<AudioTag> _readWav(_Source source) async {
    var offset = 12;
    var tag = AudioTag.empty;
    int? byteRate;
    int? dataSize;
    var guard = 0;

    while (offset + 8 <= source.length && guard++ < 256) {
      final header = await source.read(offset, 8);

      if (header.length < 8) {
        break;
      }

      final id = _ascii(header, 0, 4);
      final size = _le32(header, 4);
      final payloadStart = offset + 8;

      if (size < 0 || payloadStart + size > source.length + 1) {
        break;
      }

      if (id == 'fmt ' && size >= 12) {
        final format = await source.read(payloadStart, min(size, 16));

        if (format.length >= 12) {
          byteRate = _le32(format, 8);
        }
      } else if (id == 'data') {
        dataSize = size;
      } else if (id == 'LIST' && size >= 8) {
        tag = tag.orElse(_parseWavInfoList(await source.read(payloadStart, min(size, 1024 * 1024))));
      }

      offset = payloadStart + size + (size & 1);
    }

    if (byteRate != null && byteRate > 0 && dataSize != null && dataSize > 0) {
      return tag.orElse(AudioTag(duration: Duration(microseconds: (dataSize * 1000000 / byteRate).round())));
    }

    return tag;
  }

  AudioTag _parseWavInfoList(Uint8List data) {
    if (_ascii(data, 0, 4) != 'INFO') {
      return AudioTag.empty;
    }

    var offset = 4;
    var title = '';
    var artist = '';
    var album = '';
    int? year;
    int? track;

    while (offset + 8 <= data.length) {
      final id = _ascii(data, offset, 4);
      final size = _le32(data, offset + 4);
      offset += 8;

      if (size < 0 || offset + size > data.length) {
        break;
      }

      final value = _ascii(data, offset, size).replaceAll('\u0000', '').trim();
      offset += size + (size & 1);

      switch (id) {
        case 'INAM':
          title = value;
        case 'IART':
          artist = value;
        case 'IPRD':
          album = value;
        case 'ICRD':
          year ??= int.tryParse(RegExp(r'^\d{4}').stringMatch(value) ?? '');
        case 'ITRK':
          track ??= int.tryParse(RegExp(r'^\d+').stringMatch(value) ?? '');
      }
    }

    return AudioTag(
      title: _nullIfEmpty(title),
      artist: _nullIfEmpty(artist),
      album: _nullIfEmpty(album),
      year: year,
      trackNumber: track,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared decoding
  // ---------------------------------------------------------------------------

  String _decodeId3Text(int encoding, Uint8List bytes) {
    try {
      return switch (encoding) {
        0 => latin1.decode(bytes),
        2 => _decodeUtf16(bytes, littleEndian: false),
        3 => utf8.decode(bytes, allowMalformed: true),
        _ => _decodeUtf16(bytes, littleEndian: true),
      };
    } on Object {
      return '';
    }
  }

  String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    var start = 0;
    var little = littleEndian;

    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        little = true;
        start = 2;
      } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        little = false;
        start = 2;
      }
    }

    final units = <int>[];

    for (var index = start; index + 1 < bytes.length; index += 2) {
      units.add(little ? bytes[index] | (bytes[index + 1] << 8) : (bytes[index] << 8) | bytes[index + 1]);
    }

    return String.fromCharCodes(units);
  }

  /// Where an encoding-terminated string ends, one past its terminator.
  int _encodedStringEnd(Uint8List data, int start, int encoding) {
    if (encoding == 1 || encoding == 2) {
      var index = start;

      while (index + 1 < data.length) {
        if (data[index] == 0 && data[index + 1] == 0) {
          return index + 2;
        }

        index += 2;
      }

      return data.length;
    }

    final terminator = data.indexOf(0, start);

    return terminator < 0 ? data.length : terminator + 1;
  }

  Uint8List _deunsynchronise(Uint8List data) {
    final output = <int>[];

    for (var index = 0; index < data.length; index++) {
      output.add(data[index]);

      if (data[index] == 0xFF && index + 1 < data.length && data[index + 1] == 0x00) {
        index++;
      }
    }

    return Uint8List.fromList(output);
  }

  String _guessMime(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    if (bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'image/png';
    }

    if (bytes.length >= 4 && _ascii(bytes, 0, 4) == 'GIF8') {
      return 'image/gif';
    }

    if (bytes.length >= 12 && _ascii(bytes, 0, 4) == 'RIFF' && _ascii(bytes, 8, 4) == 'WEBP') {
      return 'image/webp';
    }

    return '';
  }

  String _pictureMime(String format) => switch (format.toUpperCase()) {
    'PNG' => 'image/png',
    'GIF' => 'image/gif',
    'BMP' => 'image/bmp',
    _ => 'image/jpeg',
  };

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final separator = path.lastIndexOf(RegExp(r'[\\/]'));

    if (dot <= separator || dot == path.length - 1) {
      return '';
    }

    return path.substring(dot + 1).toLowerCase();
  }

  // ---------------------------------------------------------------------------
  // Byte helpers
  // ---------------------------------------------------------------------------

  String _ascii(Uint8List data, int offset, int count) {
    if (offset < 0 || count <= 0 || offset >= data.length) {
      return '';
    }

    final end = min(offset + count, data.length);

    return latin1.decode(Uint8List.sublistView(data, offset, end));
  }

  String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  int _be16(Uint8List data, int offset) {
    if (offset + 2 > data.length) {
      return 0;
    }

    return (data[offset] << 8) | data[offset + 1];
  }

  int _be32(Uint8List data, int offset) {
    if (offset + 4 > data.length) {
      return 0;
    }

    return (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
  }

  int _be64(Uint8List data, int offset) {
    if (offset + 8 > data.length) {
      return 0;
    }

    var value = 0;

    for (var index = offset; index < offset + 8; index++) {
      value = (value << 8) | data[index];
    }

    return value;
  }

  int _le32(Uint8List data, int offset) {
    if (offset + 4 > data.length) {
      return 0;
    }

    return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24);
  }

  int _synchsafe32(Uint8List data, int offset) {
    if (offset + 4 > data.length) {
      return 0;
    }

    return ((data[offset] & 0x7F) << 21) |
        ((data[offset + 1] & 0x7F) << 14) |
        ((data[offset + 2] & 0x7F) << 7) |
        (data[offset + 3] & 0x7F);
  }
}

/// One MPEG audio frame header, used only to estimate a file's duration.
final class _Mp3FrameHeader {
  const _Mp3FrameHeader({
    required this.layer,
    required this.bitrate,
    required this.sampleRate,
    required this.samplesPerFrame,
    required this.sideInfoLength,
  });

  final int layer;
  final int bitrate;
  final int sampleRate;
  final int samplesPerFrame;
  final int sideInfoLength;

  static _Mp3FrameHeader? parse(Uint8List data, int offset) {
    if (offset + 4 > data.length) {
      return null;
    }

    final b1 = data[offset + 1];
    final b2 = data[offset + 2];
    final b3 = data[offset + 3];
    final versionBits = (b1 >> 3) & 0x03;

    if (versionBits == 1) {
      return null;
    }

    final layerBits = (b1 >> 1) & 0x03;

    if (layerBits == 0) {
      return null;
    }

    final layer = switch (layerBits) {
      3 => 1,
      2 => 2,
      _ => 3,
    };
    final bitrateIndex = (b2 >> 4) & 0x0F;
    final sampleRateIndex = (b2 >> 2) & 0x03;

    if (bitrateIndex == 0 || bitrateIndex == 15 || sampleRateIndex == 3) {
      return null;
    }

    final mpeg1 = versionBits == 3;
    final bitrate = _bitrate(mpeg1: mpeg1, layer: layer, index: bitrateIndex);

    if (bitrate <= 0) {
      return null;
    }

    final sampleRate = _sampleRate(mpeg1: mpeg1, versionBits: versionBits, index: sampleRateIndex);
    final mono = ((b3 >> 6) & 0x03) == 3;

    final samplesPerFrame = switch (layer) {
      1 => 384,
      2 => 1152,
      _ => mpeg1 ? 1152 : 576,
    };

    final sideInfoLength = switch (layer) {
      3 => mpeg1 ? (mono ? 17 : 32) : (mono ? 9 : 17),
      _ => 0,
    };

    return _Mp3FrameHeader(
      layer: layer,
      bitrate: bitrate,
      sampleRate: sampleRate,
      samplesPerFrame: samplesPerFrame,
      sideInfoLength: sideInfoLength,
    );
  }

  static int _bitrate({required bool mpeg1, required int layer, required int index}) {
    const mpeg1Layer1 = <int>[0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448];
    const mpeg1Layer2 = <int>[0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384];
    const mpeg1Layer3 = <int>[0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
    const mpeg2Low = <int>[0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
    const mpeg2Layer1 = <int>[0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256];

    if (mpeg1) {
      return switch (layer) {
        1 => mpeg1Layer1[index],
        2 => mpeg1Layer2[index],
        _ => mpeg1Layer3[index],
      };
    }

    return layer == 1 ? mpeg2Layer1[index] : mpeg2Low[index];
  }

  static int _sampleRate({required bool mpeg1, required int versionBits, required int index}) {
    const mpeg1Rates = <int>[44100, 48000, 32000];
    const mpeg2Rates = <int>[22050, 24000, 16000];
    const mpeg25Rates = <int>[11025, 12000, 8000];

    if (mpeg1) {
      return mpeg1Rates[index];
    }

    return versionBits == 2 ? mpeg2Rates[index] : mpeg25Rates[index];
  }
}

/// Random access over a file or a memory buffer.
abstract interface class _Source {
  int get length;

  Future<Uint8List> read(int offset, int count);
}

final class _FileSource implements _Source {
  _FileSource(this._handle, this.length);

  final RandomAccessFile _handle;

  @override
  final int length;

  @override
  Future<Uint8List> read(int offset, int count) async {
    if (offset < 0 || count <= 0 || offset >= length) {
      return Uint8List(0);
    }

    final take = min(count, length - offset);

    await _handle.setPosition(offset);

    return await _handle.read(take);
  }
}

final class _MemorySource implements _Source {
  _MemorySource(this._bytes);

  final Uint8List _bytes;

  @override
  int get length => _bytes.length;

  @override
  Future<Uint8List> read(int offset, int count) async {
    if (offset < 0 || count <= 0 || offset >= _bytes.length) {
      return Uint8List(0);
    }

    return Uint8List.sublistView(_bytes, offset, min(offset + count, _bytes.length));
  }
}
