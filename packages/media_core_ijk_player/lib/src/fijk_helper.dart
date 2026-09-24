import 'fijk_player_config.dart';
import 'package:flutter/material.dart';
import 'package:flv_lzc/fijkplayer.dart';

/// FijkPlayer Helper
class FijkHelper {
  /// Applies [config] to [player] for the upcoming open.
  ///
  /// - Named options and extra options are folded into three maps
  ///   (one write per key), so a single `Future.wait` dispatches
  ///   them concurrently without any ordering hazard.
  /// - `extraXxxOptions` are merged after the named options and can
  ///   override built-in keys.
  /// - [sourceHeaders] are merged on top of `config.headers`; source
  ///   wins because it is more specific.
  /// - A null or empty [proxyUrl] writes `''` (DIRECT).
  static Future<void> applyConfig(
    FijkPlayer player,
    FijkPlayerConfig config, {
    Map<String, String>? sourceHeaders,
    String? proxyUrl,
  }) async {
    // headers
    final mergedHeaders = <String, String>{...config.headers, ...?sourceHeaders};

    String? userAgent;
    final headerBuffer = StringBuffer();
    for (final entry in mergedHeaders.entries) {
      final key = entry.key.trim();
      final value = entry.value.replaceAll(RegExp(r'[\r\n\u0000]+'), ' ').trim();
      if (key.isEmpty || value.isEmpty) continue;

      if (key.toLowerCase() == 'user-agent') {
        userAgent = value;
      } else {
        headerBuffer.write('$key:$value\r\n');
      }
    }

    // merge the three categories
    final playerOpts = <String, Object>{
      'mediacodec': config.enableCodec ? 1 : 0,
      'mediacodec-hevc': config.enableCodec ? 1 : 0,
      'videotoolbox': config.enableCodec ? 1 : 0,
      'enable-accurate-seek': config.accurateSeek ? 1 : 0,
      'soundtouch': config.soundtouch ? 1 : 0,
      'subtitle': config.subtitle ? 1 : 0,
      'an': config.disableAudioOutput ? 1 : 0,
      ...config.extraPlayerOptions,
    };

    final hostOpts = <String, Object>{
      'request-screen-on': config.requestScreenOn ? 1 : 0,
      'request-audio-focus': (config.requestAudioFocus && !config.disableAudioOutput) ? 1 : 0,
      ...config.extraHostOptions,
    };

    final formatOpts = <String, Object>{
      'reconnect': config.reconnect ? 1 : 0,
      'timeout': config.timeout.inMicroseconds,
      'fflags': config.fflags,
      'rtsp_transport': config.rtspTransport,
      'http_proxy': proxyUrl ?? '',
      'headers': headerBuffer.toString(),
      if (userAgent != null) 'user_agent': userAgent,
      ...config.extraFormatOptions,
    };

    // dispatch concurrently
    final futures = <Future<void>>[
      for (final e in playerOpts.entries) player.setOption(FijkOption.playerCategory, e.key, e.value),
      for (final e in hostOpts.entries) player.setOption(FijkOption.hostCategory, e.key, e.value),
      for (final e in formatOpts.entries) player.setOption(FijkOption.formatCategory, e.key, e.value),
    ];

    await Future.wait(futures);
  }

  /// Formats a player position as a readable string.
  static String formatDuration(Duration duration) {
    if (duration.inMilliseconds < 0) return '-: negative';

    String two(int n) => n.toString().padLeft(2, '0');

    final minutes = two(duration.inMinutes.remainder(60));
    final seconds = two(duration.inSeconds.remainder(60));
    final hours = duration.inHours;

    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  static FijkFit getIjkBoxFit(BoxFit videoFit) {
    switch (videoFit) {
      case BoxFit.contain:
        return FijkFit.contain;
      case BoxFit.cover:
        return FijkFit.cover;
      case BoxFit.fill:
        return FijkFit.fill;
      case BoxFit.fitHeight:
        return FijkFit.fitHeight;
      case BoxFit.fitWidth:
        return FijkFit.fitWidth;
      default:
        return FijkFit.contain;
    }
  }
}
