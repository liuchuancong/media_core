/// Represents the media container format.
///
/// A [SourceFormat] describes the format/container
/// used by a media source.
///
/// It does not:
///
/// - inspect media streams
/// - detect codecs
/// - parse containers
///
/// Those belong to:
///
/// - [SourceInspector]
/// - player adapters
enum SourceFormat {
  /// Unknown format.
  unknown,

  /// MPEG transport stream.
  ///
  /// Common extension:
  /// - .ts
  ts,

  /// MPEG-4 container.
  ///
  /// Common extension:
  /// - .mp4
  mp4,

  /// Flash Video container.
  ///
  /// Common extension:
  /// - .flv
  flv,

  /// Matroska container.
  ///
  /// Common extension:
  /// - .mkv
  mkv,

  /// WebM container.
  ///
  /// Common extension:
  /// - .webm
  webm,

  /// AVI container.
  ///
  /// Common extension:
  /// - .avi
  avi,

  /// MPEG program stream.
  ///
  /// Common extension:
  /// - .mpeg
  /// - .mpg
  mpeg,

  /// HTTP Live Streaming playlist.
  ///
  /// Common extension:
  /// - .m3u8
  hls,

  /// Dynamic Adaptive Streaming playlist.
  ///
  /// Common extension:
  /// - .mpd
  dash,

  /// Ogg container.
  ///
  /// Common extension:
  /// - .ogg
  ogg,

  /// WAV audio container.
  ///
  /// Common extension:
  /// - .wav
  wav,

  /// MP3 audio format.
  ///
  /// Common extension:
  /// - .mp3
  mp3,

  /// AAC audio format.
  ///
  /// Common extension:
  /// - .aac
  aac,

  /// Custom format.
  custom,
}

/// Extensions for [SourceFormat].
extension SourceFormatExtension on SourceFormat {
  /// Whether this format represents a streaming playlist.
  bool get isStreaming {
    switch (this) {
      case SourceFormat.hls:
      case SourceFormat.dash:
        return true;

      case SourceFormat.unknown:
      case SourceFormat.ts:
      case SourceFormat.mp4:
      case SourceFormat.flv:
      case SourceFormat.mkv:
      case SourceFormat.webm:
      case SourceFormat.avi:
      case SourceFormat.mpeg:
      case SourceFormat.ogg:
      case SourceFormat.wav:
      case SourceFormat.mp3:
      case SourceFormat.aac:
      case SourceFormat.custom:
        return false;
    }
  }

  /// Whether this format usually contains video.
  bool get hasVideo {
    switch (this) {
      case SourceFormat.ts:
      case SourceFormat.mp4:
      case SourceFormat.flv:
      case SourceFormat.mkv:
      case SourceFormat.webm:
      case SourceFormat.avi:
      case SourceFormat.mpeg:
      case SourceFormat.hls:
      case SourceFormat.dash:
        return true;

      case SourceFormat.unknown:
      case SourceFormat.ogg:
      case SourceFormat.wav:
      case SourceFormat.mp3:
      case SourceFormat.aac:
      case SourceFormat.custom:
        return false;
    }
  }

  /// Whether this format is audio-only.
  bool get audioOnly {
    switch (this) {
      case SourceFormat.wav:
      case SourceFormat.mp3:
      case SourceFormat.aac:
        return true;

      case SourceFormat.unknown:
      case SourceFormat.ts:
      case SourceFormat.mp4:
      case SourceFormat.flv:
      case SourceFormat.mkv:
      case SourceFormat.webm:
      case SourceFormat.avi:
      case SourceFormat.mpeg:
      case SourceFormat.hls:
      case SourceFormat.dash:
      case SourceFormat.ogg:
      case SourceFormat.custom:
        return false;
    }
  }

  /// Returns common file extension.
  String? get extension {
    switch (this) {
      case SourceFormat.ts:
        return 'ts';

      case SourceFormat.mp4:
        return 'mp4';

      case SourceFormat.flv:
        return 'flv';

      case SourceFormat.mkv:
        return 'mkv';

      case SourceFormat.webm:
        return 'webm';

      case SourceFormat.avi:
        return 'avi';

      case SourceFormat.mpeg:
        return 'mpeg';

      case SourceFormat.hls:
        return 'm3u8';

      case SourceFormat.dash:
        return 'mpd';

      case SourceFormat.ogg:
        return 'ogg';

      case SourceFormat.wav:
        return 'wav';

      case SourceFormat.mp3:
        return 'mp3';

      case SourceFormat.aac:
        return 'aac';

      case SourceFormat.unknown:
      case SourceFormat.custom:
        return null;
    }
  }

  /// Returns readable format name.
  String get displayName {
    switch (this) {
      case SourceFormat.unknown:
        return 'unknown';

      case SourceFormat.ts:
        return 'ts';

      case SourceFormat.mp4:
        return 'mp4';

      case SourceFormat.flv:
        return 'flv';

      case SourceFormat.mkv:
        return 'mkv';

      case SourceFormat.webm:
        return 'webm';

      case SourceFormat.avi:
        return 'avi';

      case SourceFormat.mpeg:
        return 'mpeg';

      case SourceFormat.hls:
        return 'hls';

      case SourceFormat.dash:
        return 'dash';

      case SourceFormat.ogg:
        return 'ogg';

      case SourceFormat.wav:
        return 'wav';

      case SourceFormat.mp3:
        return 'mp3';

      case SourceFormat.aac:
        return 'aac';

      case SourceFormat.custom:
        return 'custom';
    }
  }
}
