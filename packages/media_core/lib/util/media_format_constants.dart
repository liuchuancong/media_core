/// Supported media formats and streaming protocols.
///
/// These sets describe recognized URL extensions and URI schemes.
/// Actual playback support depends on the selected player backend and its
/// available demuxers, decoders, and protocol handlers.
abstract final class MediaFormatConstants {
  // Common video formats
  static const Set<String> supportedFormats = {
    'mp4',
    'm4v',
    'mov',
    'mkv',
    'webm',
    'avi',
    'wmv',
    'flv',
    'f4v',
    '3gp',
    '3g2',
    'mpg',
    'mpeg',
    'm2v',
    'm2ts',
    'mts',
    'vob',
    'ts',
    'mxf',

    // Live streaming and adaptive streaming formats
    'm3u8',
    'm3u',
    'mpd',
    'ism',
    'isml',
    'ismc',
    'f4m',

    // Legacy streaming and video formats
    'asf',
    'rm',
    'rmvb',

    // Audio formats and streams
    'mp3',
    'aac',
    'm4a',
    'ac3',
    'eac3',
    'dts',
    'flac',
    'wav',
    'ogg',
    'opus',
    'oga',
    'wma',
    'ape',
    'amr',
    'aiff',

    // MPEG and MPEG-TS formats
    'm2p',
    'm2t',
    'mpe',
    'm1v',
    'm1a',
    'mpegts',

    // Other media container formats
    'nut',
    'y4m',
    'ivf',

    // Raw video streams and elementary streams
    'h264',
    'h265',
    'hevc',
    '264',
    '265',
  };

  static const Set<String> supportedProtocols = {
    // Standard web streaming protocols
    'http',
    'https',

    // Real-Time Messaging Protocol
    'rtmp',
    'rtmps',

    // Real-Time Streaming Protocol
    'rtsp',
    'rtsps',

    // Secure and low-latency streaming protocols
    'srt',

    // Network transport protocols
    'udp',
    'rtp',
    'tcp',

    // File transfer protocols
    'ftp',
    'ftps',
  };
}
