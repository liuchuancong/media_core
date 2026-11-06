import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_ingest/media_core_ingest.dart';

final class _FakeProcess implements IngestFfmpegProcess {
  final Completer<int> _exit = Completer<int>();
  bool stopped = false;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> stop() async {
    stopped = true;
    if (!_exit.isCompleted) _exit.complete(0);
  }

  void exitNow(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }
}

/// A starter that publishes the playlist path FFmpeg was handed (its last
/// argument) a moment later - the publish is what the relay waits on. The
/// relay reuses one starter for every round, so the join round is told apart
/// by its playlist name and can run on a process of its own.
final class _RoundStarter {
  _RoundStarter(this.process, {this.join, this.publish = true, bool? publishJoin})
    : publishJoin = publishJoin ?? publish;

  final _FakeProcess process;
  final _FakeProcess? join;
  final bool publish;
  final bool publishJoin;
  int calls = 0;

  Future<IngestFfmpegProcess> call(List<String> arguments) {
    calls++;
    final playlist = File(arguments.last);
    final isJoin = playlist.path.endsWith(FfmpegIngestRelay.joinPlaylistName);
    final target = isJoin ? (join ?? process) : process;
    if (isJoin ? publishJoin : publish) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 20), () {
          playlist.parent.createSync(recursive: true);
          playlist.writeAsStringSync(isJoin ? '#EXTM3U\njoin\n' : '#EXTM3U\nfirst\n', flush: true);
        }),
      );
    }
    return Future<IngestFfmpegProcess>.value(target);
  }
}

Future<String> _read(Uri url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('ffmpeg ingest arguments', () {
    test('a copy remux publishes a rolling local playlist', () {
      final arguments = FfmpegIngestRelay.buildIngestArguments(
        source: Uri.parse('https://example.com/live.flv'),
        outputDirectory: r'C:\tmp\ingest',
      );

      expect(arguments, containsAllInOrder(<String>['-i', 'https://example.com/live.flv']));
      expect(arguments, containsAllInOrder(<String>['-c', 'copy']));
      expect(arguments, containsAllInOrder(<String>['-f', 'hls']));
      expect(arguments, containsAllInOrder(<String>['-hls_list_size', '4']));
      expect(arguments, contains('delete_segments+append_list+omit_endlist'));
      expect(arguments.last, endsWith(FfmpegIngestRelay.ingestPlaylistName));
      expect(arguments, isNot(contains('-headers')));
    });

    test('headers are one CRLF-delimited field list', () {
      final arguments = FfmpegIngestRelay.buildIngestArguments(
        source: Uri.parse('https://example.com/live.m3u8'),
        outputDirectory: '/tmp/ingest',
        headers: const <String, String>{'Referer': 'https://twitcasting.tv/', 'Origin': 'https://twitcasting.tv'},
      );

      final index = arguments.indexOf('-headers');
      expect(index, greaterThanOrEqualTo(0));
      expect(arguments[index + 1], contains('Referer: https://twitcasting.tv/\r\n'));
      expect(arguments[index + 1], contains('Origin: https://twitcasting.tv\r\n'));
    });

    test('a transcode declares the codecs instead of copying', () {
      final arguments = FfmpegIngestRelay.buildIngestArguments(
        source: Uri.parse('https://example.com/live.flv'),
        outputDirectory: '/tmp/ingest',
        copyStreams: false,
        videoCodec: 'libx264',
      );

      expect(arguments, isNot(contains('copy')));
      expect(arguments, containsAllInOrder(<String>['-c:v', 'libx264']));
      expect(arguments, containsAllInOrder(<String>['-c:a', 'aac']));
    });

    test('the join round writes its own list with its own prefix', () {
      final arguments = FfmpegIngestRelay.buildJoinArguments(
        source: Uri.parse('https://example.com/fresh.flv'),
        outputDirectory: '/tmp/ingest',
      );

      expect(arguments, containsAllInOrder(<String>['-i', 'https://example.com/fresh.flv']));
      expect(arguments, contains('delete_segments+omit_endlist'));
      expect(arguments, isNot(contains('delete_segments+append_list+omit_endlist')));
      expect(arguments.last, endsWith(FfmpegIngestRelay.joinPlaylistName));
      expect(arguments.last, isNot(endsWith(FfmpegIngestRelay.ingestPlaylistName)));
      expect(arguments[arguments.indexOf('-hls_segment_filename') + 1], endsWith('join%05d.ts'));
    });
  });

  group('ffmpeg ingest relay', () {
    late _FakeProcess process;

    setUp(() => process = _FakeProcess());

    test('a process that never publishes a playlist fails the start', () async {
      await expectLater(
        FfmpegIngestRelay.start(
          source: Uri.parse('https://example.com/live.flv'),
          startFfmpeg: (_) async => process,
          startupTimeout: const Duration(milliseconds: 300),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(process.stopped, isTrue, reason: 'a failed start must not leak the process');
    });

    test('a process that exits before publishing reports its code', () async {
      final started = FfmpegIngestRelay.start(
        source: Uri.parse('https://example.com/live.flv'),
        startFfmpeg: (_) async => process,
        startupTimeout: const Duration(seconds: 5),
      );
      scheduleMicrotask(() => process.exitNow(1));

      await expectLater(started, throwsA(isA<FormatException>()));
    });
  });

  group('ffmpeg ingest renewal', () {
    test('a renewal proves the fresh address, then cuts the serving over in place', () async {
      final first = _FakeProcess();
      final join = _FakeProcess();
      final starter = _RoundStarter(first, join: join);
      final relay = await FfmpegIngestRelay.start(
        source: Uri.parse('https://example.com/live.flv'),
        startFfmpeg: starter.call,
        startupTimeout: const Duration(seconds: 5),
      );
      try {
        expect(relay.source, Uri.parse('https://example.com/live.flv'));

        final renewed = await relay.renewAddress(
          Uri.parse('https://example.com/fresh.flv'),
          headers: const <String, String>{'Referer': 'https://example.com/'},
        );
        expect(renewed, isTrue);
        await pumpEventQueue();
        expect(relay.source, Uri.parse('https://example.com/fresh.flv'));
        expect(relay.hasExited, isFalse);
        expect(starter.calls, 2, reason: 'the original round and the join round');
        expect(first.stopped, isTrue, reason: 'the round the renewal replaced is stopped');
        expect(join.stopped, isFalse);

        final served = await _read(relay.inputUri);
        expect(
          served,
          '#EXTM3U\njoin\n',
          reason: 'the join playlist is served under the name the player already knows',
        );
      } finally {
        await relay.close();
      }
    });

    test('a renewal that never publishes leaves the running round alone', () async {
      final first = _FakeProcess();
      final join = _FakeProcess();
      final relay = await FfmpegIngestRelay.start(
        source: Uri.parse('https://example.com/live.flv'),
        startFfmpeg: _RoundStarter(first, join: join, publishJoin: false).call,
        startupTimeout: const Duration(seconds: 5),
      );
      try {
        final renewed = await relay.renewAddress(Uri.parse('https://example.com/fresh.flv'));
        expect(renewed, isFalse);
        expect(first.stopped, isFalse, reason: 'a failed renewal keeps the old address');
        expect(relay.source, Uri.parse('https://example.com/live.flv'));
        expect(relay.hasExited, isFalse);
        expect(await _read(relay.inputUri), '#EXTM3U\nfirst\n');
        expect(join.stopped, isTrue, reason: 'the round that failed to publish is not leaked');
      } finally {
        await relay.close();
      }
    });

    test('concurrent renewals share one join round', () async {
      final first = _FakeProcess();
      final join = _FakeProcess();
      final starter = _RoundStarter(first, join: join);
      final relay = await FfmpegIngestRelay.start(
        source: Uri.parse('https://example.com/live.flv'),
        startFfmpeg: starter.call,
        startupTimeout: const Duration(seconds: 5),
      );
      try {
        final results = await Future.wait(<Future<bool>>[
          relay.renewAddress(Uri.parse('https://example.com/fresh-a.flv')),
          relay.renewAddress(Uri.parse('https://example.com/fresh-b.flv')),
        ]);
        expect(results, everyElement(isTrue));
        expect(starter.calls, 2, reason: 'one renewal, not one per caller');
        expect(relay.source, Uri.parse('https://example.com/fresh-a.flv'));
      } finally {
        await relay.close();
      }
    });

    test('a round that died on its own is revived by a renewal', () async {
      final first = _FakeProcess();
      final join = _FakeProcess();
      final relay = await FfmpegIngestRelay.start(
        source: Uri.parse('https://example.com/live.flv'),
        startFfmpeg: _RoundStarter(first, join: join).call,
        startupTimeout: const Duration(seconds: 5),
      );
      try {
        first.exitNow(1);
        await pumpEventQueue();
        expect(relay.hasExited, isTrue);

        final renewed = await relay.renewAddress(Uri.parse('https://example.com/fresh.flv'));
        expect(renewed, isTrue);
        await pumpEventQueue();
        expect(relay.hasExited, isFalse, reason: 'the relay runs on the join round now');
        expect(relay.source, Uri.parse('https://example.com/fresh.flv'));
      } finally {
        await relay.close();
      }
    });

    test('a DASH merge does not renew', () async {
      final process = _FakeProcess();
      final relay = await FfmpegIngestRelay.startDashMerge(
        videoSource: Uri.parse('https://example.com/video.m4s'),
        audioSource: Uri.parse('https://example.com/audio.m4s'),
        startFfmpeg: _RoundStarter(process).call,
        startupTimeout: const Duration(seconds: 5),
      );
      try {
        expect(await relay.renewAddress(Uri.parse('https://example.com/fresh.m4s')), isFalse);
        expect(relay.source, Uri.parse('https://example.com/video.m4s'));
      } finally {
        await relay.close();
      }
    });
  });
}
