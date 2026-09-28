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
  /// 1. **macOS** — always `no`. The bundled libmpv's VideoToolbox path
  ///    is unstable with the Flutter texture surface, and the platform
  ///    profile pins this regardless of what was persisted on another
  ///    device.
  /// 2. **Android compat mode** — `mediacodec` (see [_isCompatMode]).
  /// 3. **Windows RTX VSR** — `d3d11va`, required by the filter chain.
  /// 4. **Expert output** — the user-picked decoder, normalised for
  ///    the current platform.
  /// 5. **Default** — `auto-safe` when [enableCodec] is on, else `no`.
  void _resolvePreferredHardwareDecoder() {
    final platform = defaultTargetPlatform;

    if (platform == TargetPlatform.macOS) {
      _preferredHardwareDecoder = 'no';
      return;
    }

    if (_isCompatMode) {
      _preferredHardwareDecoder = 'mediacodec';
      return;
    }

    // RTX VSR requires the D3D11VA decode path; it takes precedence
    // over a user pick because the filter chain cannot run otherwise.
    if (platform == TargetPlatform.windows && enableRtxVsr) {
      _preferredHardwareDecoder = 'd3d11va';
      return;
    }

    if (customPlayerOutput) {
      _preferredHardwareDecoder = MpvPlatformProfile.normalizeHardwareDecoderForPlatform(
        videoHardwareDecoder,
        platform,
      );
      return;
    }

    _preferredHardwareDecoder = enableCodec ? 'auto-safe' : 'no';
  }

  /// Builds the video controller.
  ///
  /// The three-way branch is platform-gated: compat mode only ever
  /// fires on Android, RTX VSR only ever fires on Windows, and the
  /// driver / decoder strings always pass through the platform
  /// normaliser so a persisted Android choice cannot leak into an
  /// iOS build.
  ///
  /// The `scale` / `width` / `height` / `SurfaceProducer` fields come
  /// straight from [MediaKitPlayerConfig]; they are ignored by the
  /// compat-mode branch, which intentionally pins the legacy surface
  /// path.
  mkv.VideoController _buildVideoController() {
    final platform = defaultTargetPlatform;

    if (_isCompatMode) {
      return mkv.VideoController(
        player,
        configuration: const mkv.VideoControllerConfiguration(
          vo: 'mediacodec_embed',
          hwdec: 'mediacodec',
          enableAndroidSurfaceProducer: false,
          androidAttachSurfaceAfterVideoParameters: false,
        ),
      );
    }

    final isMacOS = platform == TargetPlatform.macOS;

    if (customPlayerOutput) {
      final normalizedVideoOutput = MpvPlatformProfile.normalizeVideoOutputDriverForPlatform(
        videoOutputDriver,
        platform,
      );

      final normalizedHardwareDecoder = isMacOS
          ? 'no'
          : MpvPlatformProfile.normalizeHardwareDecoderForPlatform(videoHardwareDecoder, platform);

      return mkv.VideoController(
        player,
        configuration: mkv.VideoControllerConfiguration(
          vo: normalizedVideoOutput,
          hwdec: normalizedHardwareDecoder,
          scale: config.videoScale,
          width: config.videoOutputWidth,
          height: config.videoOutputHeight,
          enableHardwareAcceleration: !isMacOS && normalizedHardwareDecoder != 'no',
          enableAndroidSurfaceProducer: config.enableAndroidSurfaceProducer,
          androidAttachSurfaceAfterVideoParameters: config.androidAttachSurfaceAfterVideoParameters,
        ),
      );
    }

    return mkv.VideoController(
      player,
      configuration: mkv.VideoControllerConfiguration(
        scale: config.videoScale,
        width: config.videoOutputWidth,
        height: config.videoOutputHeight,
        enableHardwareAcceleration: isMacOS ? false : enableCodec,
        hwdec: isMacOS ? 'no' : null,
        enableAndroidSurfaceProducer: config.enableAndroidSurfaceProducer,
        androidAttachSurfaceAfterVideoParameters: config.androidAttachSurfaceAfterVideoParameters,
      ),
    );
  }

  /// Applies the native live-stream property contract to mpv.
  ///
  /// Platform-specific blocks are fenced by explicit
  /// [defaultTargetPlatform] checks so cross-platform settings never
  /// bleed.
  Future<void> _applyNativeLiveProperties() async {
    if (_player?.platform == null) return;

    final platform = defaultTargetPlatform;
    final profile = _device;

    await _setNativeProperty(
      'protocol_whitelist',
      'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto,rtmp,rtmps,rtsp,srt',
    );

    await _setNativeProperty('demuxer-lavf-probesize', '2097152');

    await _setNativeProperty('demuxer-lavf-analyzeduration', '2');

    await LiveBufferPolicy.apply(_setNativeProperty, profile: profile);

    await _setNativeProperty('network-timeout', '15');

    // Drop a failing hw decoder after one bad frame.
    await _setNativeProperty('hwdec-software-fallback', '1');

    await _applyDecodeCostPolicy(
      MpvDecodePolicy.resolve(
        preferredHwdec: _preferredHardwareDecoder,
        codec: _videoCodec,
        width: _width ?? 0,
        height: _height ?? 0,
        device: _device,
        codecs: _codecs,
      ),
    );

    if (profile.isLowEnd) {
      await _setNativeProperty('audio-buffer', '0.4');

      await _setNativeProperty(
        'stream-lavf-o',
        'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,'
            'reconnect_delay_max=2',
      );
    }

    // --- Android-only: mediacodec direct surface rendering ---------------
    if (platform == TargetPlatform.android) {
      await _setNativeProperty('mediacodec-surface-iostream', 'yes');

      await _setNativeProperty('mediacodec-embed-surface-landscape', 'yes');
    }

    // --- macOS-only: force software decoding -----------------------------
    if (platform == TargetPlatform.macOS) {
      await _setNativeProperty('hwdec', 'no');
    }

    // --- Windows-only: optional RTX Video Super Resolution ---------------
    if (platform == TargetPlatform.windows && enableRtxVsr) {
      await _setNativeProperty('hwdec', 'd3d11va');

      await _setNativeProperty('vf', 'd3d11vpp=scale=2:scaling-mode=nvidia');
    }

    // --- Audio output driver (per-platform default) ----------------------
    final audioOutput = MpvPlatformProfile.effectiveAudioOutputDriverForPlatform(
      customOutput: customPlayerOutput,
      configuredDriver: audioOutputDriver ?? 'auto',
      platform: platform,
    );

    if (audioOutput != null) {
      await _setNativeProperty('ao', audioOutput);
    }

    // --- Escape hatch: user-supplied properties applied last -------------
    for (final entry in config.extraProperties.entries) {
      await _setNativeProperty(entry.key, entry.value);
    }
  }

  Future<void> _applyDecodeCostPolicy(MpvDecodePolicy policy) async {
    final threads = policy.threads;

    if (threads != null) {
      await _setNativeProperty('vd-lavc-threads', threads.toString());
    }

    if (policy.tuneForSmallDevice) {
      await _setNativeProperty('vd-lavc-o', 'lowres=1');

      await _setNativeProperty('vd-lavc-skiploopfilter', 'nonref');

      return;
    }

    await _setNativeProperty('vd-lavc-o', 'lowres=0');

    await _setNativeProperty('vd-lavc-skiploopfilter', 'default');
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
    final forced = _softwareDecoderNextOpen;

    _softwareDecoderNextOpen = false;

    final policy = MpvDecodePolicy.resolve(
      preferredHwdec: _preferredHardwareDecoder,
      forceSoftware: forced,
      codec: _videoCodec,
      width: _width ?? 0,
      height: _height ?? 0,
      device: _device,
      codecs: _codecs,
    );

    await _setNativeProperty('hwdec', policy.hwdec);

    await _applyDecodeCostPolicy(policy);

    MediaCoreLog.debug(
      LogCategory.renderer,
      'decode policy: ${policy.rationale} '
      '(hwdec=${policy.hwdec}, codec=$_videoCodec, threads=${policy.threads}, '
      'lowEnd=${_device.isLowEnd}, deviceKnown=${_device.isKnown})',
    );
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
