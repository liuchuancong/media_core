import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:media_core/media_core.dart';
import 'package:media_core_mpv_audio/media_core_mpv_audio.dart';

/// The mpv_audio_kit adapter spike (spectrum plan, engine side): opens the
/// known sine on the adapter, forwards the engine's FFT taps to stdout and
/// applies one typed effect, proving the three things this backend was
/// adopted for — playback, the tap streams and the effects chain.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final wav = await _writeSineWav();
  stdout.writeln('wav: $wav');

  final adapter = MpvAudioPlayerAdapter();
  await adapter.initialize(
    PlayerAdapterContext.basic(playerId: PlayerId('spike'), sessionId: SessionId('spike')),
  );
  stdout.writeln('adapter initialized; engine=${adapter.player != null}');

  var fftFrames = 0;
  var pcmFrames = 0;
  FftFrame? first;
  final engine = adapter.player!;
  engine.stream.fft.listen((frame) {
    fftFrames++;
    first ??= frame;
  });
  engine.stream.pcm.listen((_) => pcmFrames++);

  final events = <String>[];
  adapter.events.listen((event) {
    final name = event.toString().split('.').first;
    if (events.isEmpty || events.last != name) {
      events.add(name);
    }
  });

  await adapter.open(PlayerSource.of(id: SourceId('spike'), uri: Uri.file(wav)));
  await adapter.play();
  stdout.writeln('opened + playing');

  // One typed effect, applied live: a 6 dB low-shelf lift (FFmpeg bass).
  await engine.setAudioEffects([const BassEffect(gain: 6)]);
  stdout.writeln('effects applied');

  await Future<void>.delayed(const Duration(seconds: 12));
  await adapter.dispose();

  final frame = first;
  stdout
    ..writeln('---')
    ..writeln('events: ${events.take(12).join(' ')}')
    ..writeln('fft frames=$fftFrames pcm frames=$pcmFrames over ~11 s');
  if (frame != null) {
    stdout.writeln(
      'first fft: bands=${frame.bands.length} '
      'peakBand=${frame.bands.indexOf(frame.bands.reduce(math.max))} '
      '(440 Hz in 64 log bands lands in band ~5-8)',
    );
  } else {
    stdout.writeln('FFT: NONE — tap did not flow');
  }
  exit(frame != null && fftFrames > 100 ? 0 : 1);
}

/// 12 s of 440 Hz sine at half amplitude, stereo 48 kHz 16-bit.
Future<String> _writeSineWav() async {
  const sampleRate = 48000;
  const seconds = 12;
  const channels = 2;
  const amplitude = 0.5;
  const samplesPerChannel = sampleRate * seconds;
  const dataSize = samplesPerChannel * channels * 2;
  final bytes = BytesBuilder(copy: false);
  final header = Uint8List(44)
    ..setRange(0, 4, 'RIFF'.codeUnits)
    ..setRange(8, 12, 'WAVE'.codeUnits)
    ..setRange(12, 16, 'fmt '.codeUnits)
    ..setRange(36, 40, 'data'.codeUnits);
  ByteData.sublistView(header)
    ..setUint32(4, 36 + dataSize, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * channels * 2, Endian.little)
    ..setUint16(32, channels * 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(40, dataSize, Endian.little);
  bytes.add(header);
  final body = ByteData(dataSize);
  for (var i = 0; i < samplesPerChannel; i++) {
    final sample = (amplitude * 32767 * math.sin(2 * math.pi * 440 * i / sampleRate)).round();
    for (var c = 0; c < channels; c++) {
      body.setInt16(i * channels * 2 + c * 2, sample, Endian.little);
    }
  }
  bytes.add(body.buffer.asUint8List());
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}mak_spike_tone.wav');
  await file.writeAsBytes(bytes.takeBytes(), flush: true);
  return file.path;
}
