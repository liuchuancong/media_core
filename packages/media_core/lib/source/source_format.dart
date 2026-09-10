/// Describes the container or media file format of a source.
///
/// [SourceFormat] describes the format of the media resource itself.
/// Transport protocols such as HTTP, HLS, RTSP, and DASH belong to
/// [SourceProtocol] instead.
enum SourceFormat {
  /// Unknown or not yet determined.
  unknown,

  /// MPEG-4 container.
  mp4,

  /// MPEG-TS container.
  mpegTs,

  /// Matroska container.
  mkv,

  /// WebM container.
  webm,

  /// AVI container.
  avi,

  /// QuickTime / MOV container.
  mov,

  /// Flash Video container.
  flv,

  /// Ogg container.
  ogg,

  /// WebVTT subtitle format.
  webVtt,

  /// SubRip subtitle format.
  srt,

  /// Advanced SubStation Alpha subtitle format.
  ass,

  /// MPEG-DASH manifest.
  mpd,

  /// HTTP Live Streaming manifest.
  m3u8,

  /// Audio-only MPEG format.
  mp3,

  /// AAC audio format.
  aac,

  /// FLAC audio format.
  flac,

  /// WAV audio format.
  wav,

  /// Opus audio format.
  opus,

  /// Application-defined custom format.
  custom,
}

/// Extensions for [SourceFormat].
extension SourceFormatX on SourceFormat {
  /// Whether this format is unknown.
  bool get isUnknown => this == SourceFormat.unknown;

  /// Whether this format is known.
  bool get isKnown => this != SourceFormat.unknown;

  /// Whether this is a video container format.
  bool get isVideo {
    switch (this) {
      case SourceFormat.mp4:
      case SourceFormat.mpegTs:
      case SourceFormat.mkv:
      case SourceFormat.webm:
      case SourceFormat.avi:
      case SourceFormat.mov:
      case SourceFormat.flv:
        return true;

      case SourceFormat.unknown:
      case SourceFormat.webVtt:
      case SourceFormat.srt:
      case SourceFormat.ass:
      case SourceFormat.mpd:
      case SourceFormat.m3u8:
      case SourceFormat.mp3:
      case SourceFormat.aac:
      case SourceFormat.flac:
      case SourceFormat.wav:
      case SourceFormat.opus:
      case SourceFormat.ogg:
      case SourceFormat.custom:
        return false;
    }
  }

  /// Whether this is an audio format.
  bool get isAudio {
    switch (this) {
      case SourceFormat.mp3:
      case SourceFormat.aac:
      case SourceFormat.flac:
      case SourceFormat.wav:
      case SourceFormat.opus:
      case SourceFormat.ogg:
        return true;

      case SourceFormat.unknown:
      case SourceFormat.mp4:
      case SourceFormat.mpegTs:
      case SourceFormat.mkv:
      case SourceFormat.webm:
      case SourceFormat.avi:
      case SourceFormat.mov:
      case SourceFormat.flv:
      case SourceFormat.webVtt:
      case SourceFormat.srt:
      case SourceFormat.ass:
      case SourceFormat.mpd:
      case SourceFormat.m3u8:
      case SourceFormat.custom:
        return false;
    }
  }

  /// Whether this is a subtitle format.
  bool get isSubtitle {
    switch (this) {
      case SourceFormat.webVtt:
      case SourceFormat.srt:
      case SourceFormat.ass:
        return true;

      case SourceFormat.unknown:
      case SourceFormat.mp4:
      case SourceFormat.mpegTs:
      case SourceFormat.mkv:
      case SourceFormat.webm:
      case SourceFormat.avi:
      case SourceFormat.mov:
      case SourceFormat.flv:
      case SourceFormat.mpd:
      case SourceFormat.m3u8:
      case SourceFormat.mp3:
      case SourceFormat.aac:
      case SourceFormat.flac:
      case SourceFormat.wav:
      case SourceFormat.opus:
      case SourceFormat.ogg:
      case SourceFormat.custom:
        return false;
    }
  }

  /// Whether this is a streaming manifest format.
  bool get isManifest {
    return this == SourceFormat.m3u8 || this == SourceFormat.mpd;
  }

  /// Returns the conventional file extension without the leading dot.
  String? get extension {
    switch (this) {
      case SourceFormat.mp4:
        return 'mp4';
      case SourceFormat.mpegTs:
        return 'ts';
      case SourceFormat.mkv:
        return 'mkv';
      case SourceFormat.webm:
        return 'webm';
      case SourceFormat.avi:
        return 'avi';
      case SourceFormat.mov:
        return 'mov';
      case SourceFormat.flv:
        return 'flv';
      case SourceFormat.ogg:
        return 'ogg';
      case SourceFormat.webVtt:
        return 'vtt';
      case SourceFormat.srt:
        return 'srt';
      case SourceFormat.ass:
        return 'ass';
      case SourceFormat.mpd:
        return 'mpd';
      case SourceFormat.m3u8:
        return 'm3u8';
      case SourceFormat.mp3:
        return 'mp3';
      case SourceFormat.aac:
        return 'aac';
      case SourceFormat.flac:
        return 'flac';
      case SourceFormat.wav:
        return 'wav';
      case SourceFormat.opus:
        return 'opus';
      case SourceFormat.unknown:
      case SourceFormat.custom:
        return null;
    }
  }

  /// Returns the stable string representation of this format.
  String get value => name;
}
