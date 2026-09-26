/// Resolves the upstream proxy URL for the next open.
///
/// The value is handed to FFmpeg's `avio.http_proxy`, which expects a URL
/// (`http://host:port`). An empty string means DIRECT and the option is
/// cleared.
typedef FvpProxyUrlResolver = String Function({required bool privateInput});

/// Open-time configuration for the fvp adapter.
///
/// Every field is applied to the libmdk player before `prepare()` runs.
/// Surface concerns (fit, fill, render-target clamp, tunnel decoding) live in
/// [FvpVideoConfig] instead.
final class FvpPlayerConfig {
  const FvpPlayerConfig({
    this.proxyUrlResolver,
    this.enableCodec = true,
    this.videoDecoders,
    this.audioBackends,
    this.legacyHevcFlvHosts = defaultLegacyHevcFlvHosts,
    this.extraProperties = const <String, String>{},
  });

  /// CDNs observed serving legacy "codec id 12" HEVC FLV.
  ///
  /// libmdk decodes those streams, but some Android hardware HEVC decoders
  /// reject the input as "Unsupported input buffer" without reporting an error,
  /// so the engine never advances to its next decoder and only audio plays. The
  /// adapter therefore decodes them in software on Android (see
  /// `FvpPlayerAdapter.videoDecodersFor`).
  ///
  /// Which CDNs do this is deployment knowledge, so it is configuration with a
  /// default rather than a constant: an app serving other rooms passes its own
  /// list, and an empty list disables the workaround.
  static const Set<String> defaultLegacyHevcFlvHosts = <String>{
    '.livetech.shopee.co.id',
    '.livestream.shopee.co.id',
    '.17app.co',
  };

  /// Resolver for `avio.http_proxy`; empty string = DIRECT.
  ///
  /// A loopback input (a local relay) must resolve to the empty string, or the
  /// player would send the loopback request through the proxy as well.
  final FvpProxyUrlResolver? proxyUrlResolver;

  /// Master hardware-decoding switch.
  ///
  /// `true` keeps the platform hardware decoder first in the priority list with
  /// FFmpeg and dav1d as software fallbacks; `false` decodes in software only.
  final bool enableCodec;

  /// Explicit video decoder priority.
  ///
  /// Overrides the platform default derived from [enableCodec] *and* the
  /// legacy-HEVC software rule. Names are libmdk decoder names (`AMediaCodec`,
  /// `VT`, `D3D11`, `VAAPI`, `FFmpeg`, `dav1d`, …).
  final List<String>? videoDecoders;

  /// Audio output backends, in priority order; null keeps the platform default.
  ///
  /// [FvpPlayerAdapter.audioBackends] returns the Android list that avoids
  /// libmdk's AAudio output.
  final List<String>? audioBackends;

  /// Host suffixes whose FLV may carry the legacy HEVC spelling.
  ///
  /// Empty disables the workaround.
  final Set<String> legacyHevcFlvHosts;

  /// Escape hatch: additional libmdk properties applied after the built-in
  /// contract.
  ///
  /// Keys and values are passed straight to `setProperty`. Anything listed
  /// here wins over the adapter's own value for the same key.
  final Map<String, String> extraProperties;

  /// Live-stream properties the adapter applies to every open.
  ///
  /// These mirror fvp's own `video_player` backend and are what make a live
  /// FLV/HLS source open reliably: extension-agnostic demuxing, an explicitly
  /// whitelisted protocol set (no `srt`/`ftp`, so a source on those protocols
  /// does not silently reach a demuxer the build may not carry) and reconnect
  /// with a bounded backoff.
  static const Map<String, String> defaultLiveProperties = <String, String>{
    'avformat.strict': 'experimental',
    'avformat.safe': '0',
    'avio.reconnect': '1',
    'avio.reconnect_delay_max': '7',
    'avformat.extension_picky': '0',
    'avformat.allowed_segment_extensions': 'ALL',
    'avio.protocol_whitelist': 'file,http,https,tls,tcp,udp,crypto,httpproxy,data',
  };

  /// Copy with modifications.
  FvpPlayerConfig copyWith({
    FvpProxyUrlResolver? proxyUrlResolver,
    bool? enableCodec,
    List<String>? videoDecoders,
    List<String>? audioBackends,
    Set<String>? legacyHevcFlvHosts,
    Map<String, String>? extraProperties,
  }) {
    return FvpPlayerConfig(
      proxyUrlResolver: proxyUrlResolver ?? this.proxyUrlResolver,
      enableCodec: enableCodec ?? this.enableCodec,
      videoDecoders: videoDecoders ?? this.videoDecoders,
      audioBackends: audioBackends ?? this.audioBackends,
      legacyHevcFlvHosts: legacyHevcFlvHosts ?? this.legacyHevcFlvHosts,
      extraProperties: extraProperties ?? this.extraProperties,
    );
  }
}
