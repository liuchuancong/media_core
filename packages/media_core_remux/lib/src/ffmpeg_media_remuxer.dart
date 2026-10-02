import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

import 'package:media_core/composition/media_timeline.dart';
import 'package:media_core/remux/media_remuxer.dart';
import 'package:media_core/source/media_source.dart';

import 'package:media_core_remux/src/remux_failed_error.dart';
import 'package:media_core/source/media_track.dart';
import 'package:media_core/source/media_track_type.dart';
import 'package:media_core/source/source_headers.dart';



/// Runs one complete FFmpeg invocation and answers with its exit code.
///
/// The seam every part of this remuxer's decision logic is tested
/// through; [FfmpegKitRunner] is the production implementation.
typedef FfmpegRunner = Future<int> Function(List<String> arguments);

/// Starts FFmpeg processes through `ffmpeg_kit_extended_flutter`.
///
/// Mirrors the executor `media_core_recording_ffmpeg` uses, with one
/// difference: a remux is a finished-when-it's-finished batch job, so
/// there is no progress or cancellation surface here — only the exit
/// code.
final class FfmpegKitRunner {
  /// Creates the runner.
  ///
  /// [createSession] exists for tests; production callers omit it.
  FfmpegKitRunner({
    FFmpegSession Function(
      List<String> arguments, {
      FFmpegSessionCompleteCallback? completeCallback,
    })?
    createSession,
  }) : _createSession = createSession ?? FFmpegSession.createFromArguments;

  final FFmpegSession Function(
    List<String> arguments, {
    FFmpegSessionCompleteCallback? completeCallback,
  })
  _createSession;

  bool _initialized = false;
  Completer<void>? _inFlightInitialize;

  /// Prepares the native FFmpeg once; safe to call concurrently.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final pending = _inFlightInitialize;
    if (pending != null) {
      return pending.future;
    }
    final completer = _inFlightInitialize = Completer<void>();
    try {
      await FFmpegKitExtended.initialize();
      _initialized = true;
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _inFlightInitialize = null;
    }
  }

  /// Runs [arguments] to completion and returns FFmpeg's exit code.
  Future<int> run(List<String> arguments) async {
    await initialize();

    final completion = Completer<int>();

    final session = _createSession(
      arguments,
      completeCallback: (completed) {
        if (!completion.isCompleted) {
          // getReturnCode is only meaningful after the native call has
          // reported back, which is exactly what this callback marks.
          completion.complete(completed.getReturnCode());
        }
      },
    );

    session.execute();

    return completion.future;
  }
}

/// The [MediaRemuxer] for platforms that run `ffmpeg_kit_extended_flutter`.
///
/// One leg, every platform: **Android, iOS, macOS, Windows and Linux** all
/// fold their DASH pair through the same stream copy, which is what keeps
/// a single set of failure modes and one FFmpeg binary in the app instead
/// of a per-platform muxer stack with per-platform bugs.
///
/// The copy is `-c copy` only: samples are moved, never re-encoded, so
/// codecs survive unchanged (HEVC stays HEVC) and the CPU cost is IO-bound
/// rather than codec-bound. Alignment comes from [MediaTimeline]: each
/// essence's aligned offset is applied with `-itsoffset` before its own
/// `-i`, which shifts that input's timestamps on the shared clock while
/// leaving its media content untouched.
///
/// The output is necessarily a single-file progressive container — MP4
/// here, chosen by the output extension. DASH is a *delivery* model
/// (manifest plus segments); once two essences are folded into one
/// stream there is nothing left to deliver as fragments, and a merged
/// file's job is to be seekable by one URL from a single-input engine,
/// which is exactly what a `moov` sample table provides.
///
/// Request headers are per-input (`-user_agent` and `-headers` are
/// options *of the following* `-i`), which is what Bilibili needs: the
/// gate applies to both essences and the maps can differ.
///
/// What this does not do:
///
/// - Subtitle tracks are dropped. MP4 subtitle muxing (tx3g/CMFC) is
///   outside the platform muxer's practical scope, and a subtitle that
///   matters belongs on a backend that selects it natively.
/// - Live streams. A stream copy runs to EOF, and a live DASH period
///   never ends; composite live sources should go to a backend whose
///   composite support is native or externalAudio instead.
final class FfmpegMediaRemuxer implements MediaRemuxer {
  /// Creates an FFmpeg remuxer.
  ///
  /// [run] overrides how FFmpeg is executed (tests inject a fake
  /// [FfmpegRunner]); [outputDirectory] overrides where the merged
  /// file is written — defaults to a fresh temp directory per process.
  FfmpegMediaRemuxer({
    FfmpegRunner? run,
    Future<String> Function()? outputDirectory,
  }) : _run = run ?? _defaultRunner.run,
       _outputDirectory = outputDirectory ?? _defaultOutputDirectory;

  static final FfmpegKitRunner _defaultRunner = FfmpegKitRunner();

  static Future<String> _defaultOutputDirectory() async {
    final dir = await Directory.systemTemp.createTemp('media_core_remux_');
    return dir.path;
  }

  final FfmpegRunner _run;
  final Future<String> Function() _outputDirectory;

  /// Builds the FFmpeg argument list for [source], writing to [outputPath].
  ///
  /// Exposed for tests and for hosts that need to inspect or extend
  /// the command; [remux] calls this for every merge.
  static List<String> argumentsFor(
    CompositeMediaSource source, {
    required String outputPath,
  }) {
    final video = source.primaryVideo;
    final audio = source.primaryAudio;
    if (video == null || audio == null) {
      throw UnsupportedError(
        'FfmpegMediaRemuxer needs one video and one audio essence; '
        'this composite has ${video == null ? 'no video' : 'no audio'}.',
      );
    }

    final timeline = MediaTimeline.from(source);

    return <String>[
      '-y',
      ..._inputArguments(
        video,
        offset: timeline[video]?.offset ?? Duration.zero,
      ),
      ..._inputArguments(
        audio,
        offset: timeline[audio]?.offset ?? Duration.zero,
      ),
      // One essence each; map them explicitly so FFmpeg does not pick
      // "best" on its own and silently drop the intended pair.
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      '-c',
      'copy',
      // DASH essences have sparse timestamps between periods; a large
      // interleave delta keeps the copy from aborting on the gap.
      '-max_interleave_delta',
      '0',
      outputPath,
    ];
  }

  static List<String> _inputArguments(
    MediaTrack track, {
    required Duration offset,
  }) {
    final arguments = <String>[];

    if (offset > Duration.zero) {
      final seconds = (offset.inMicroseconds / 1000000).toStringAsFixed(3);
      arguments.addAll(<String>['-itsoffset', seconds]);
    }

    final headers = track.headers;
    // SourceHeaders[] lookup is case-insensitive by contract, so the
    // exact spelling the provider used does not matter here.
    final userAgent = headers?['User-Agent'];
    if (userAgent != null && userAgent.trim().isNotEmpty) {
      arguments.addAll(<String>['-user_agent', userAgent]);
    }

    final headerLines = _headerLines(headers, excludeUserAgent: true);
    if (headerLines != null) {
      arguments.addAll(<String>['-headers', headerLines]);
    }

    arguments.addAll(<String>['-i', track.uri.toString()]);
    return arguments;
  }

  static String? _headerLines(
    SourceHeaders? headers, {
    required bool excludeUserAgent,
  }) {
    if (headers == null || headers.isEmpty) {
      return null;
    }
    final buffer = StringBuffer();
    for (final name in headers.names) {
      if (excludeUserAgent && name.toLowerCase() == 'user-agent') {
        continue;
      }
      final value = headers[name];
      if (value == null || value.isEmpty) {
        continue;
      }
      // FFmpeg's http option expects CRLF-joined lines, and an input
      // that is not a CRLF pair is a request-header smuggling risk:
      // values containing newlines must never reach the builder.
      if (value.contains('\r') || value.contains('\n')) {
        continue;
      }
      buffer.write('$name: $value\r\n');
    }
    final lines = buffer.toString();
    return lines.isEmpty ? null : lines;
  }

  @override
  Future<MediaSource> remux(CompositeMediaSource source) async {
    final directory = await _outputDirectory();
    final path = Uri.file(
      '$directory${Platform.pathSeparator}'
      'remux_${DateTime.now().microsecondsSinceEpoch}.mp4',
    ).toFilePath();

    final exitCode = await _run(argumentsFor(source, outputPath: path));
    if (exitCode != 0) {
      // A non-zero copy can still leave a partial MP4 whose moov box
      // (or any box at all) never arrived; handing back its path would
      // let a single-URL backend play a silent or truncated file.
      await _deleteQuietly(path);
      throw RemuxFailedError(
        'FFmpeg stream copy failed with exit code $exitCode for '
        '${source.primaryVideo?.uri}',
      );
    }

    return ProgressiveMediaSource(
      track: MediaTrack(
        uri: Uri.file(path),
        kind: MediaTrackType.video,
        mimeType: 'video/mp4',
        metadata: const <String, Object?>{
          'media_core.remuxed': true,
          'media_core.remuxer': 'ffmpeg',
        },
      ),
    );
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Best-effort cleanup; the returned failure is what the caller acts on.
    }
  }
}

/// Whether this platform has an FFmpeg the remuxer can drive.
///
/// `ffmpeg_kit_extended_flutter` ships Android, iOS, macOS, Windows and
/// Linux; a web build has no process to run, so it gets no remuxer and
/// the planner's [UnsupportedPlan] stays the honest answer for a
/// composite source on a single-URL backend there.
bool get remuxSupported {
  if (kIsWeb) {
    return false;
  }
  return Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows ||
      Platform.isLinux;
}

/// The remuxer for the current platform, or `null` where there is none.
///
/// One muxing path on every supported platform, so a bug, a container
/// quirk and a header-handling rule all mean the same thing everywhere:
///
/// ```dart
/// final kernel = PlayerKernel(remuxer: platformRemuxer());
/// ```
MediaRemuxer? platformRemuxer({FfmpegRunner? ffmpegRun}) {
  if (!remuxSupported) {
    return null;
  }
  return FfmpegMediaRemuxer(run: ffmpegRun);
}
