part of 'media_kit_player_adapter.dart';

/// Platform-aware engine configuration: hardware decoder preference,
/// the native mpv property set, live tuning and the decode-cost policy.
extension _MediaKitEngineConfig on MediaKitPlayerAdapter {
  // ---------------------------------------------------------------------------
  // Platform-aware engine configuration
  // ---------------------------------------------------------------------------

  /// Resolves the hardware decoder preference.
  ///
  /// Precedence, top to bottom:
  ///
  /// 1. **Host pick** — the decoder the host declared, normalised for the
  ///    current platform.
  /// 2. **Default** — `auto-safe` when [enableCodec] is on, else `no`.
  void _resolvePreferredHardwareDecoder() {
    final platform = defaultTargetPlatform;

    // The decoder is the host's call: its pick, or its on/off switch. The
    // adapter never picks a tuning value on its own.
    final hostPick = videoHardwareDecoder;
    if (hostPick != null && hostPick.isNotEmpty) {
      _preferredHardwareDecoder = MpvPlatformProfile.normalizeHardwareDecoderForPlatform(hostPick, platform);
      return;
    }

    _preferredHardwareDecoder = enableCodec ? 'auto-safe' : 'no';
  }

  mkv.VideoController _buildVideoController() {
    final platform = defaultTargetPlatform;

    if (customPlayerOutput) {
      final normalizedVideoOutput = MpvPlatformProfile.normalizeVideoOutputDriverForPlatform(
        videoOutputDriver,
        platform,
      );

      final hostPick = videoHardwareDecoder;
      final normalizedHardwareDecoder = hostPick == null || hostPick.isEmpty
          ? null
          : MpvPlatformProfile.normalizeHardwareDecoderForPlatform(hostPick, platform);

      return mkv.VideoController(
        player,
        configuration: mkv.VideoControllerConfiguration(
          vo: normalizedVideoOutput,
          hwdec: normalizedHardwareDecoder,
          scale: config.videoScale,
          width: config.videoOutputWidth,
          height: config.videoOutputHeight,
          enableHardwareAcceleration: normalizedHardwareDecoder != 'no',
          androidAttachSurfaceAfterVideoParameters: config.androidAttachSurfaceAfterVideoParameters,
        ),
      );
    }

    // No preset: the host's own flags and picks, or mpv's defaults.
    return mkv.VideoController(
      player,
      configuration: mkv.VideoControllerConfiguration(
        scale: config.videoScale,
        width: config.videoOutputWidth,
        height: config.videoOutputHeight,
        enableHardwareAcceleration: enableCodec,
        hwdec: videoHardwareDecoder,
        androidAttachSurfaceAfterVideoParameters: config.androidAttachSurfaceAfterVideoParameters,
      ),
    );
  }

  /// Applies the properties the host declared, and nothing else.
  ///
  /// Every tuning value a live-stream host wants (demuxer probes, buffer
  /// budget, timeouts, decoder fallbacks, platform quirks) belongs to that
  /// host: it travels in [MediaKitPlayerConfig.extraProperties] and is written
  /// verbatim, last. The adapter itself only applies
  /// what the host set through its own config fields.
  Future<void> _applyHostDeclaredProperties() async {
    if (_player?.platform == null) return;

    final platform = defaultTargetPlatform;

    // A host-picked decoder wins; a requested software fallback forces "no"
    // for this open so the retry can prove whether software decoding helps.
    final forcedSoftware = _softwareDecoderNextOpen;
    _softwareDecoderNextOpen = false;

    if (forcedSoftware) {
      await _setNativeProperty('hwdec', 'no');
    } else if (videoHardwareDecoder != null && videoHardwareDecoder!.isNotEmpty) {
      final normalized = MpvPlatformProfile.normalizeHardwareDecoderForPlatform(videoHardwareDecoder!, platform);
      await _setNativeProperty('hwdec', normalized);
    }

    final audioOutput = audioOutputDriver;
    if (audioOutput != null && audioOutput.isNotEmpty && audioOutput != 'auto') {
      await _setNativeProperty('ao', audioOutput);
    }

    if (platform == TargetPlatform.windows && enableRtxVsr) {
      await _setNativeProperty('hwdec', 'd3d11va');
      await _setNativeProperty('vf', 'd3d11vpp=scale=2:scaling-mode=nvidia');
    }

    final videoOutput = videoOutputDriver;
    if (customPlayerOutput && videoOutput.isNotEmpty && videoOutput != 'auto') {
      await _setNativeProperty(
        'vo',
        MpvPlatformProfile.normalizeVideoOutputDriverForPlatform(videoOutput, platform),
      );
    }

    for (final entry in config.extraProperties.entries) {
      await _setNativeProperty(entry.key, entry.value);
    }
  }

  Future<void> _setNativeProperty(String name, String value) async {
    final native = _player?.platform;

    if (native == null) return;

    try {
      // ignore: avoid_dynamic_calls
      await (native as dynamic).setProperty(name, value);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _applyDecoderPolicy() async {
    // The decoder a host picked travels in its config; a software fallback
    // requested by the host is applied by _applyHostDeclaredProperties on the
    // next open. Nothing here decides a tuning value on the host's behalf.
  }

  Future<void> _applyProxy() async {
    final native = _player?.platform;

    if (native == null) return;

    try {
      // A loopback input is a local server the caller started (a relay it
      // owns, typically): it must never be sent through a proxy, whatever
      // [setPrivateInput] was last told.
      final private = _privateInput || _isLoopback(_currentUrl);
      final url = proxyUrlResolver?.call(privateInput: private) ?? '';

      // Explicitly writing an empty proxy clears a previous
      // source's proxy state instead of allowing it to persist.
      // ignore: avoid_dynamic_calls
      await (native as dynamic).setProperty('http-proxy', url);

      _privateInput = false;
    } catch (_) {
      // Best-effort.
    }
  }

  /// Whether [url] addresses this machine.
  ///
  /// The source URI is what the native player is handed, so this is where a
  /// caller-owned loopback relay shows up.
  static bool _isLoopback(String? url) {
    if (url == null) return false;
    final host = Uri.tryParse(url)?.host.toLowerCase();

    return host == 'localhost' || host == '127.0.0.1' || host == '::1' || host == '[::1]';
  }}
