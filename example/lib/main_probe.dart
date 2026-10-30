import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' as mk;

/// Stage B1 + B2 verification, self-driving: synthesizes a sine WAV, opens
/// it on a bare media_kit player, mounts the astats tap via the probe and
/// prints the numbers the go/no-go needs to stdout, then exits with the
/// verdict.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  mk.MediaKit.ensureInitialized();

  final wav = await _writeSineWav();
  stdout.writeln('wav: $wav');

  final player = mk.Player();
  final probe = mk.MediaKitAudioTapProbe(player);

  probe.frames.listen((frame) {
    if (_printedLevel) return;
    _printedLevel = true;
    stdout.writeln(
      'level: peakDb=${(frame.overallPeakDb ?? double.nan).toStringAsFixed(1)} '
      'rmsDb=${(frame.overallRmsDb ?? double.nan).toStringAsFixed(1)} '
      '(sine at half amplitude expects peak near -6 dBFS)',
    );
  });
  probe.stats.listen((stats) {
    stdout.writeln(
      'frames=${stats.frames} hz=${stats.hz.toStringAsFixed(1)} '
      'lastParseUs=${stats.lastParseUs} maxParseUs=${stats.maxParseUs}',
    );
  });

  player.stream.error.listen((e) => stdout.writeln('player error: $e'));

  await player.open(mk.Media(wav));
  await player.play();
  await Future<void>.delayed(const Duration(seconds: 2));
  final started = await probe.start();
  stdout.writeln(started ? 'tap started: ${mk.MediaKitAudioTapProbe.filterEntry}' : 'TAP FAILED TO START');

  await Future<void>.delayed(const Duration(seconds: 20));
  await probe.stop();
  await player.dispose();

  stdout.writeln('---');
  stdout.writeln(
    'B2 verdict on the last stats line above: rate needs >=30 Hz, parse needs <2 ms',
  );
  exit(0);
}

var _printedLevel = false;

/// 30 s of 440 Hz sine at half amplitude, stereo 48 kHz 16-bit — a real
/// decoded PCM stream for astats to measure, no network involved.
Future<String> _writeSineWav() async {
  const sampleRate = 48000;
  const seconds = 30;
  const channels = 2;
  const amplitude = 0.5;
  const samplesPerChannel = sampleRate * seconds;
  final dataSize = samplesPerChannel * channels * 2;
  final bytes = BytesBuilder(copy: false);
  final header = Uint8List(44)
    ..setRange(0, 4, 'RIFF'.codeUnits)
    ..setRange(8, 12, 'WAVE'.codeUnits)
    ..setRange(12, 16, 'fmt '.codeUnits)
    ..setRange(36, 40, 'data'.codeUnits);
  final view = ByteData.sublistView(header);
  view.setUint32(4, 36 + dataSize, Endian.little);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * channels * 2, Endian.little);
  view.setUint16(32, channels * 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  view.setUint32(40, dataSize, Endian.little);
  bytes.add(header);
  final body = ByteData(dataSize);
  for (var i = 0; i < samplesPerChannel; i++) {
    final sample = (amplitude * 32767 * math.sin(2 * math.pi * 440 * i / sampleRate)).round();
    for (var c = 0; c < channels; c++) {
      body.setInt16(i * channels * 2 + c * 2, sample, Endian.little);
    }
  }
  bytes.add(body.buffer.asUint8List());
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}media_core_probe_tone.wav');
  await file.writeAsBytes(bytes.takeBytes(), flush: true);
  return file.path;
}
