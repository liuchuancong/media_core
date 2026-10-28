import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_audio/media_core_audio.dart';

Uint8List _concat(List<List<int>> parts) => Uint8List.fromList(<int>[for (final part in parts) ...part]);

List<int> _be32(int value) => <int>[(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];

List<int> _le16(int value) => <int>[value & 0xFF, (value >> 8) & 0xFF];

List<int> _le32(int value) => <int>[value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF];

List<int> _synchsafe(int value) => <int>[(value >> 21) & 0x7F, (value >> 14) & 0x7F, (value >> 7) & 0x7F, value & 0x7F];

final List<int> _png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x01];

List<int> _id3Frame(String id, List<int> payload) => <int>[
  ...latin1.encode(id),
  ..._be32(payload.length),
  0,
  0,
  ...payload,
];

List<int> _id3Text(String text) => <int>[3, ...utf8.encode(text)];

List<int> _id3Tag(List<List<int>> frames) {
  final body = <int>[for (final frame in frames) ...frame];

  return <int>[...latin1.encode('ID3'), 3, 0, 0, ..._synchsafe(body.length), ...body];
}

/// Two valid MPEG-1 Layer III frames (128 kbps, 44.1 kHz) so duration has
/// something to read after the tag.
List<int> _mp3Frames() {
  final frame = <int>[0xFF, 0xFB, 0x90, 0x00, ...List<int>.filled(413, 0)];

  return <int>[...frame, ...frame];
}

List<int> _id3v1({String title = 'V1 Title'}) {
  return List<int>.filled(128, 0)
    ..setRange(0, 3, latin1.encode('TAG'))
    ..setRange(3, 3 + title.length, latin1.encode(title))
    ..[125] = 0
    ..[126] = 7;
}

List<int> _flacBlock({required int type, required List<int> data, required bool last}) => <int>[
  (last ? 0x80 : 0) | type,
  (data.length >> 16) & 0xFF,
  (data.length >> 8) & 0xFF,
  data.length & 0xFF,
  ...data,
];

List<int> _vorbisComment(List<String> entries) => <int>[
  ..._le32(4),
  ...latin1.encode('test'),
  ..._le32(entries.length),
  for (final entry in entries) ...<int>[..._le32(utf8.encode(entry).length), ...utf8.encode(entry)],
];

List<int> _flacFile() {
  const sampleRate = 44100;
  const totalSamples = 441000; // 10 seconds
  const packed = (sampleRate << 44) | (1 << 41) | (15 << 36) | totalSamples;
  final streamInfo = <int>[
    0, 0, 0, 0, // block sizes
    0, 0, 0, 0, 0, 0, // frame sizes
    ...List<int>.generate(8, (index) => (packed >> (56 - index * 8)) & 0xFF),
    ...List<int>.filled(16, 0),
  ];
  final picture = <int>[
    ..._be32(3),
    ..._be32(latin1.encode('image/png').length),
    ..._be32(0), // description length
    ...latin1.encode('image/png'),
    ..._be32(64),
    ..._be32(64),
    ..._be32(24),
    ..._be32(0),
    ..._be32(_png.length),
    ..._png,
  ];

  return <int>[
    ...latin1.encode('fLaC'),
    ..._flacBlock(type: 0, data: streamInfo, last: false),
    ..._flacBlock(
      type: 4,
      data: _vorbisComment(<String>['TITLE=Flac Song', 'ARTIST=Flac Artist', 'LYRICS=[00:00.00]flac lyric']),
      last: false,
    ),
    ..._flacBlock(type: 6, data: picture, last: true),
  ];
}

List<int> _atom(String type, List<int> payload) => <int>[
  ..._be32(payload.length + 8),
  ...latin1.encode(type),
  ...payload,
];

List<int> _mp4Data(int kind, List<int> payload) => _atom('data', <int>[..._be32(kind), 0, 0, 0, 0, ...payload]);

List<int> _mp4File() {
  final mvhd = <int>[
    0, 0, 0, 0, // version/flags
    0, 0, 0, 0, // created
    0, 0, 0, 0, // modified
    ..._be32(1000),
    ..._be32(60000), // 60 seconds
    ...List<int>.filled(80, 0),
  ];
  final ilst = _atom('ilst', <int>[
    ..._atom('©nam', _mp4Data(1, utf8.encode('Mp4 Song'))),
    ..._atom('©ART', _mp4Data(1, utf8.encode('Mp4 Artist'))),
    ..._atom('©alb', _mp4Data(1, utf8.encode('Mp4 Album'))),
    ..._atom('©lyr', _mp4Data(1, utf8.encode('[00:00.00]mp4 lyric'))),
    ..._atom('trkn', _mp4Data(0, <int>[0, 0, 0, 5, 0, 9])),
    ..._atom('covr', _mp4Data(14, _png)),
  ]);
  final meta = _atom('meta', <int>[
    0,
    0,
    0,
    0,
    ..._atom('hdlr', <int>[0, 0, 0, 0]),
    ...ilst,
  ]);
  final moov = _atom('moov', <int>[..._atom('mvhd', mvhd), ..._atom('udta', meta)]);

  return <int>[..._atom('ftyp', latin1.encode('M4A ')), ...moov];
}

List<int> _oggPage(List<int> packet, int sequence, {required bool first}) {
  final lacing = <int>[];
  var remaining = packet.length;

  while (remaining >= 255) {
    lacing.add(255);
    remaining -= 255;
  }

  lacing.add(remaining);

  return <int>[
    ...latin1.encode('OggS'),
    0,
    if (first) 2 else 0,
    ...List<int>.filled(8, 0),
    ..._le32(1),
    ..._le32(sequence),
    ...List<int>.filled(4, 0),
    lacing.length,
    ...lacing,
    ...packet,
  ];
}

List<int> _oggFile() {
  final head = <int>[...latin1.encode('OpusHead'), 1, 2, ..._le16(312), ..._le32(48000), ..._le16(0), 0];
  final tags = <int>[
    ...latin1.encode('OpusTags'),
    ..._le32(4),
    ...latin1.encode('test'),
    ..._le32(1),
    ..._le32('TITLE=Ogg Song'.length),
    ...latin1.encode('TITLE=Ogg Song'),
  ];

  return <int>[..._oggPage(head, 0, first: true), ..._oggPage(tags, 1, first: false)];
}

List<int> _wavFile() {
  const byteRate = 176400;
  const dataSize = 88200; // half a second
  final info = <int>[
    ...latin1.encode('INFO'),
    ...latin1.encode('INAM'),
    ..._le32(8),
    ...latin1.encode('Wav Song'),
    ...latin1.encode('IART'),
    ..._le32(10),
    ...latin1.encode('Wav Artist'),
  ];
  final fmt = <int>[..._le16(1), ..._le16(2), ..._le32(44100), ..._le32(byteRate), ..._le16(4), ..._le16(16)];
  final body = <int>[
    ...latin1.encode('WAVE'),
    ...latin1.encode('fmt '),
    ..._le32(fmt.length),
    ...fmt,
    ...latin1.encode('LIST'),
    ..._le32(info.length),
    ...info,
    ...latin1.encode('data'),
    ..._le32(dataSize),
    ...List<int>.filled(dataSize, 0),
  ];

  return <int>[...latin1.encode('RIFF'), ..._le32(body.length), ...body];
}

void main() {
  const reader = AudioTagReader();

  test('reads ID3v2 frames, embedded lyric and picture on MP3', () async {
    final tag = _id3Tag(<List<int>>[
      _id3Frame('TIT2', _id3Text('Tagged Title')),
      _id3Frame('TPE1', _id3Text('Tagged Artist')),
      _id3Frame('TALB', _id3Text('Tagged Album')),
      _id3Frame('TRCK', _id3Text('3/12')),
      _id3Frame('TYER', _id3Text('2021')),
      _id3Frame('USLT', <int>[3, ...latin1.encode('eng'), 0, ...utf8.encode('[00:00.00]embedded lyric')]),
      _id3Frame('APIC', <int>[3, ...latin1.encode('image/png'), 0, 3, 0, ..._png]),
    ]);

    final parsed = await reader.parse(_concat(<List<int>>[tag, _mp3Frames(), _id3v1()]), extension: 'mp3');

    expect(parsed.title, 'Tagged Title');
    expect(parsed.artist, 'Tagged Artist');
    expect(parsed.album, 'Tagged Album');
    expect(parsed.trackNumber, 3);
    expect(parsed.year, 2021);
    expect(parsed.lyric, '[00:00.00]embedded lyric');
    expect(parsed.picture?.mimeType, 'image/png');
    expect(parsed.picture?.bytes, _png);
    expect(parsed.duration, isNotNull);
    expect(parsed.duration!.inMilliseconds, greaterThan(0));
  });

  test('falls back to ID3v1 when no v2 tag exists', () async {
    final parsed = await reader.parse(_concat(<List<int>>[_mp3Frames(), _id3v1()]), extension: 'mp3');

    expect(parsed.title, 'V1 Title');
    expect(parsed.trackNumber, 7);
  });

  test('reads FLAC comments, duration and picture', () async {
    final parsed = await reader.parse(_concat(<List<int>>[_flacFile()]), extension: 'flac');

    expect(parsed.title, 'Flac Song');
    expect(parsed.artist, 'Flac Artist');
    expect(parsed.lyric, '[00:00.00]flac lyric');
    expect(parsed.duration, const Duration(seconds: 10));
    expect(parsed.picture?.mimeType, 'image/png');
    expect(parsed.picture?.bytes, _png);
  });

  test('reads MP4 ilst tags, duration and cover', () async {
    final parsed = await reader.parse(_concat(<List<int>>[_mp4File()]), extension: 'm4a');

    expect(parsed.title, 'Mp4 Song');
    expect(parsed.artist, 'Mp4 Artist');
    expect(parsed.album, 'Mp4 Album');
    expect(parsed.trackNumber, 5);
    expect(parsed.lyric, '[00:00.00]mp4 lyric');
    expect(parsed.duration, const Duration(seconds: 60));
    expect(parsed.picture?.mimeType, 'image/png');
  });

  test('reads Opus comments in Ogg', () async {
    final parsed = await reader.parse(_concat(<List<int>>[_oggFile()]), extension: 'opus');

    expect(parsed.title, 'Ogg Song');
  });

  test('reads WAV INFO tags and duration', () async {
    final parsed = await reader.parse(_concat(<List<int>>[_wavFile()]), extension: 'wav');

    expect(parsed.title, 'Wav Song');
    expect(parsed.artist, 'Wav Artist');
    expect(parsed.duration, const Duration(milliseconds: 500));
  });

  test('an untagged file is empty rather than an error', () async {
    final parsed = await reader.parse(Uint8List.fromList(<int>[1, 2, 3, 4]), extension: 'ape');

    expect(parsed.isEmpty, isTrue);
  });

  test('LocalMusicSource titles local songs from their tags', () async {
    final directory = await Directory.systemTemp.createTemp('media_core_audio_tag_test');
    addTearDown(() => directory.delete(recursive: true));

    final path = '${directory.path}/tagged.mp3';
    final tag = _id3Tag(<List<int>>[
      _id3Frame('TIT2', _id3Text('Local Title')),
      _id3Frame('TPE1', _id3Text('Local Artist')),
      _id3Frame('TALB', _id3Text('Local Album')),
      _id3Frame('USLT', <int>[3, ...latin1.encode('eng'), 0, ...utf8.encode('[00:00.00]embedded')]),
      _id3Frame('APIC', <int>[3, ...latin1.encode('image/png'), 0, 3, 0, ..._png]),
    ]);

    await File(path).writeAsBytes(_concat(<List<int>>[tag, _mp3Frames()]));

    final source = LocalMusicSource(roots: <String>[directory.path]);
    final tracks = await source.listTracks();
    final track = tracks.single;

    expect(track.title, 'Local Title');
    expect(track.artist, 'Local Artist');
    expect(track.album, 'Local Album');
    expect(track.duration, isNotNull);

    expect((await source.resolveLyric(track))?.lyric, '[00:00.00]embedded');
    expect((await source.coverOf(track))?.bytes, _png);

    // The sidecar is the file the viewer can edit, so it wins.
    await File('${directory.path}/tagged.lrc').writeAsString('[00:00.00]sidecar');
    expect((await source.resolveLyric(track))?.lyric, '[00:00.00]sidecar');
  });
}
