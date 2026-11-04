import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

/// What kind of stream one entry of an [FfmpegMediaInfo] describes.
enum FfmpegStreamKind {
  /// A picture stream.
  video,

  /// A sound stream.
  audio,

  /// A subtitle stream.
  subtitle,

  /// A data stream (timecode, telemetry).
  data,

  /// A font or otherwise attached stream.
  attachment,

  /// A stream whose type the container does not name.
  unknown,
}

/// One stream of a probed file: the figures FFprobe reads from the container,
/// zero or empty when that stream does not carry them.
///
/// One model for every stream rather than a class per kind: a caller reads the
/// fields its own kind has, and a field a stream does not carry stays at its
/// zero value instead of being absent from the type.
final class FfmpegStreamInfo {
  /// Creates a stream summary.
  const FfmpegStreamInfo({
    this.index = -1,
    this.kind = FfmpegStreamKind.unknown,
    this.codec = '',
    this.codecLong = '',
    this.pixelFormat = '',
    this.width = 0,
    this.height = 0,
    this.frameRate = 0,
    this.bitrate = 0,
    this.sampleRate = 0,
    this.channelLayout = '',
    this.displayAspectRatio = '',
  });

  /// The stream's own index in the container.
  final int index;

  /// Whether this is a video, audio, subtitle or other stream.
  final FfmpegStreamKind kind;

  /// The short codec name (`h264`, `aac`).
  final String codec;

  /// The codec's long description.
  final String codecLong;

  /// The pixel format (`yuv420p`, `fltp`), empty when the stream has none.
  final String pixelFormat;

  /// Video width in pixels; 0 for a stream without a picture.
  final int width;

  /// Video height in pixels; 0 for a stream without a picture.
  final int height;

  /// Frames per second; 0 when the container does not name one.
  final double frameRate;

  /// The stream's bitrate in bits per second; 0 when it is not reported.
  final int bitrate;

  /// Audio sample rate in hertz; 0 for a stream without audio.
  final int sampleRate;

  /// The channel layout (`stereo`, `5.1`), empty when the stream has none.
  final String channelLayout;

  /// The display aspect ratio (`16:9`), empty when the stream has none.
  final String displayAspectRatio;

  /// The height as a viewer names a picture size (`1080P`), empty without a
  /// video stream.
  String get resolutionLabel => height <= 0 ? '' : '${height}P';
}

/// What FFprobe answered about one file: its container, the figures that apply
/// to the whole file, and every stream it holds.
///
/// A probe is a native call the caller opts into, so one call returns
/// everything the container can say; a caller takes the fields it needs —
/// [duration] for verification, [video] for a card's resolution — instead of
/// asking FFprobe again for each new field the app grows.
final class FfmpegMediaInfo {
  /// Creates a media summary.
  const FfmpegMediaInfo({
    this.duration,
    this.format = '',
    this.longFormat = '',
    this.bitrate = 0,
    this.size = 0,
    this.streams = const [],
  });

  /// The file's duration; null when the container does not state one.
  final Duration? duration;

  /// The container's short name (`mp4`, `mpegts`), empty when unknown.
  final String format;

  /// The container's long description, empty when unknown.
  final String longFormat;

  /// The file's overall bitrate in bits per second; 0 when not reported.
  final int bitrate;

  /// The file's size in bytes; 0 when not reported.
  final int size;

  /// Every stream the file holds, in the container's own order.
  final List<FfmpegStreamInfo> streams;

  /// The first video stream, or null for a file without a picture.
  FfmpegStreamInfo? get video => streams.where((stream) => stream.kind == FfmpegStreamKind.video).firstOrNull;

  /// The first audio stream, or null for a silent file.
  FfmpegStreamInfo? get audio => streams.where((stream) => stream.kind == FfmpegStreamKind.audio).firstOrNull;

  /// Every video stream (a multi-angle or multi-codec take can hold more than
  /// one).
  Iterable<FfmpegStreamInfo> get videos => streams.where((stream) => stream.kind == FfmpegStreamKind.video);

  /// The picture's width, or 0 without a video stream.
  int get width => video?.width ?? 0;

  /// The picture's height, or 0 without a video stream.
  int get height => video?.height ?? 0;

  /// The picture's frame rate, or 0 when it is not reported.
  double get frameRate => video?.frameRate ?? 0;

  /// The video codec's short name, empty without a video stream.
  String get videoCodec => video?.codec ?? '';
}

/// What a file on disk actually contains, as far as FFprobe can tell.
///
/// An exit code says a process ended and the journal says which files were
/// closed; neither says the bytes form a stream a decoder can open. FFprobe is
/// the only thing in this dependency that can say that, and it is a native call,
/// so it sits behind a seam: the verification logic is judged in tests against a
/// probe that returns fixed answers, and production uses [FFprobeKitFfmpegProbe].
abstract interface class FfmpegProbe {
  /// Everything [path]'s container states, or null when it cannot be read.
  ///
  /// Null is the answer for a missing file, an unparsable container and a
  /// native layer that is not initialized. The caller treats all three the same
  /// way — *unverified* — because a probe that cannot answer is not evidence
  /// that the file is bad.
  Future<FfmpegMediaInfo?> infoOf(String path);
}

/// The one figure most callers ask for, read from [FfmpegProbe.infoOf].
extension FfmpegProbeDuration on FfmpegProbe {
  /// Duration of the media at [path], or null when it cannot be determined.
  Future<Duration?> durationOf(String path) async => (await infoOf(path))?.duration;
}

/// [FfmpegProbe] backed by the plugin's own FFprobe.
///
/// Uses `MediaInformationSession`, which is the plugin's parsed `-show_format`
/// path, rather than shelling out to an ffprobe command line: the arguments are
/// built natively, so a path with spaces or quotes cannot break them.
final class FFprobeKitFfmpegProbe implements FfmpegProbe {
  /// Creates a probe.
  ///
  /// [timeout] bounds a single native probe call. Five seconds is generous for
  /// a local MPEG-TS segment (the container is read from the front) and still
  /// short enough that a stuck FFprobe cannot hold a `stop()` open.
  const FFprobeKitFfmpegProbe({this.timeout = 5000});

  /// FFprobe's per-call timeout, in milliseconds.
  final int timeout;

  @override
  Future<FfmpegMediaInfo?> infoOf(String path) async {
    try {
      final session = await MediaInformationSession.fromPath(path, timeout: timeout).executeAsync();
      final information = session.getMediaInformation();
      if (information == null) return null;
      return FfmpegMediaInfo(
        duration: _secondsOf(information.duration),
        format: information.format ?? '',
        longFormat: information.longFormat ?? '',
        bitrate: _intOf(information.bitrate),
        size: _intOf(information.size),
        streams: [for (final stream in information.streams) _streamOf(stream)],
      );
    } on Object catch (_) {
      // A probe that throws is a probe that has no answer. Verification is
      // something a recording reports, not something that can fail one - and
      // what it can throw is whatever the native binding decides to raise, which
      // is exactly why there is no `on` clause here.
      return null;
    }
  }

  static FfmpegStreamInfo _streamOf(StreamInformation stream) => FfmpegStreamInfo(
    index: stream.index ?? -1,
    kind: _kindOf(stream.type),
    codec: stream.codec ?? '',
    codecLong: stream.codecLong ?? '',
    pixelFormat: stream.format ?? '',
    width: stream.width ?? 0,
    height: stream.height ?? 0,
    frameRate: _fpsOf(stream.averageFrameRate ?? stream.realFrameRate),
    bitrate: _intOf(stream.bitrate),
    sampleRate: _intOf(stream.sampleRate),
    channelLayout: stream.channelLayout ?? '',
    displayAspectRatio: stream.displayAspectRatio ?? '',
  );

  static FfmpegStreamKind _kindOf(String? type) => switch ((type ?? '').toLowerCase()) {
    'video' => FfmpegStreamKind.video,
    'audio' => FfmpegStreamKind.audio,
    'subtitle' => FfmpegStreamKind.subtitle,
    'data' => FfmpegStreamKind.data,
    'attachment' => FfmpegStreamKind.attachment,
    _ => FfmpegStreamKind.unknown,
  };

  /// A container's seconds ("12.345678") as a duration.
  static Duration? _secondsOf(String? value) {
    final seconds = double.tryParse((value ?? '').trim());
    return seconds == null || seconds <= 0 ? null : Duration(milliseconds: (seconds * 1000).round());
  }

  /// A numeric string as an int; 0 for anything else (including "N/A").
  static int _intOf(String? value) => int.tryParse((value ?? '').trim()) ?? 0;

  /// "30000/1001", "50/1" or "50" as a number; 0 when it reads as nothing.
  static double _fpsOf(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 0;
    final parts = text.split('/');
    final numerator = double.tryParse(parts.first);
    if (numerator == null || numerator <= 0) return 0;
    final denominator = parts.length > 1 ? double.tryParse(parts[1]) : 1;
    if (denominator == null || denominator <= 0) return 0;
    final fps = numerator / denominator;
    return fps.isFinite && fps > 0 ? fps : 0;
  }
}
