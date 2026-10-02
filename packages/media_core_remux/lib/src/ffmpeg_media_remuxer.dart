import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

import 'package:media_core/composition/media_timeline.dart';
import 'package:media_core/remux/media_remuxer.dart';
import 'package:media_core/source/media_source.dart';
import 'package:media_core/source/media_track.dart';
import 'package:media_core/source/media_track_type.dart';
import 'package:media_core/source/source_headers.dart';

import 'package:media_core_remux/src/android_media_remuxer.dart';

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

/// Cross-platform [MediaRemuxer] that folds a DASH pair with an FFmpeg
/// stream copy.
///
/// The second leg of the remux contract, and the one that runs on
/// every platform:
///
/// - **Android** has two working legs. [AndroidMediaRemuxer] (the
///   platform's MediaExtractor/MediaMuxer) is the lighter default —
///   no FFmpeg binary in the process; this class is the explicit
///   alternative via `preference: PlatformRemuxerPreference.ffmpeg`
///   for hosts that want one muxing code path on every platform, or
///   the automatic fallback when the plugin is not attached.
/// - **iOS / macOS / Windows / Linux** run here through
///   `ffmpeg_kit_extended_flutter` (same pinned build the recording
///   package uses), which is the only muxing stack available on all
///   of them at once. A native AVFoundation (`AVMutableComposition` +
///   `AVAssetExportSession`) or Media Foundation (SourceReader +
///   SinkWriter) leg can replace Apple/Windows use later without
///   touching callers — they all answer the same [MediaRemuxer].
///
/// The copy is `-c copy` only: samples are moved, never re-encoded, so
/// codecs survive unchanged and the CPU cost is IO-bound rather than
/// codec-bound. Alignment comes from [MediaTimeline] the same way the
/// Android leg gets it: each essence's aligned offset is applied with
/// `-itsoffset` before its own `-i`, which shifts that input's
/// timestamps on the shared clock while leaving its media content
/// untouched.
///
/// Request headers are per-input (`-user_agent` and `-headers` are
/// options *of the following* `-i`), which is exactly what Bilibili
/// needs: the gate applies to both essences but the maps can differ.
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

/// How [platformRemuxer] should choose on Android, where two legs work.
enum PlatformRemuxerPreference {
  /// Android: the native MediaExtractor/MediaMuxer leg when the plugin
  /// is attached, FFmpeg stream copy otherwise. Every other platform:
  /// FFmpeg. This is the default — native first, because it costs no
  /// FFmpeg binary and is the lighter path on the one platform that
  /// has both.
  auto,

  /// Force the Android MediaExtractor/MediaMuxer leg. `null` on other
  /// platforms or when the plugin is not attached — never a silent
  /// fall to FFmpeg, because a caller picking this option is doing so
  /// specifically to avoid loading FFmpeg in-process.
  androidNative,

  /// Force the FFmpeg stream-copy leg everywhere, Android included.
  /// A caller picks this to keep one muxing code path across every
  /// platform (one set of failure modes, one binary), or when the
  /// platform stack rejects a specific container the provider serves.
  ffmpeg,
}

/// The remuxer this platform should use, or `null` when this platform
/// has none for the requested [preference].
///
/// Selection is capability-first, matching how the rest of media_core
/// treats declared support: on Android the native MediaMuxer is
/// preferred where attached and FFmpeg covers the rest; [preference]
/// pins the choice when a host knows which leg it wants.
///
/// ```dart
/// // Default: native on Android, FFmpeg elsewhere.
/// final kernel = PlayerKernel(remuxer: await platformRemuxer());
///
/// // One code path on every platform, at the cost of the FFmpeg binary.
/// final kernel = PlayerKernel(
///   remuxer: await platformRemuxer(
///     preference: PlatformRemuxerPreference.ffmpeg,
///   ),
/// );
/// ```
Future<MediaRemuxer?> platformRemuxer({
  PlatformRemuxerPreference preference = PlatformRemuxerPreference.auto,
  FfmpegRunner? ffmpegRun,
}) async {
  switch (preference) {
    case PlatformRemuxerPreference.ffmpeg:
      return FfmpegMediaRemuxer(run: ffmpegRun);

    case PlatformRemuxerPreference.androidNative:
      if (!Platform.isAndroid) {
        return null;
      }
      final android = AndroidMediaRemuxer();
      return await android.isAvailable() ? android : null;

    case PlatformRemuxerPreference.auto:
      if (Platform.isAndroid) {
        final android = AndroidMediaRemuxer();
        if (await android.isAvailable()) {
          return android;
        }
      }
      return FfmpegMediaRemuxer(run: ffmpegRun);
  }
}
