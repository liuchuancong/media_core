# media_core_fvp

fvp (libmdk) backend adapter for the [media_core](../media_core) player framework.

## What it gives you

libmdk ships a current FFmpeg and prefers the platform hardware decoder
(MediaCodec, VideoToolbox, D3D11, VAAPI) with FFmpeg and dav1d as software
fallbacks. It reads sources the older bundled engines drop — most notably the
legacy `codec id 12` HEVC FLV that media_kit's libmpv plays as audio only — and
it can decode in software when a device's hardware path refuses a stream.

That makes it the engine to register when a room must still play after the
default engine failed, rather than being reported as unavailable.

## Usage

```dart
final registry = PlayerAdapterRegistry();
registerFvpRegistry(registry);            // priority 80 by default

// or into a DefaultPlayerAdapterFactory
final factory = DefaultPlayerAdapterFactory();
registerFvpFactory(factory);
```

Render the surface with the adapter's own texture:

```dart
FvpVideoView(adapter: adapter as FvpPlayerAdapter)
```

or drive it from the adapter's listenables (`textureListenable`,
`sizeListenable`, `fitListenable`, `buildSurface`) when the app owns the widget
tree.

Configuration:

```dart
FvpPlayerConfig(
  proxyUrlResolver: ({required bool privateInput}) => privateInput ? '' : 'http://127.0.0.1:7897',
  enableCodec: true,
  extraProperties: const {'avformat.fflags': '+nobuffer'},
  // The defaults cover Android's audio backends and the legacy-HEVC hosts.
  legacyHevcFlvHosts: FvpPlayerConfig.defaultLegacyHevcFlvHosts,
  audioBackends: FvpPlayerAdapter.audioBackends(),
);
FvpVideoConfig(maxWidth: 1920, maxHeight: 1080, fit: BoxFit.contain);
```

Two platform rules are built in and can be overridden through the config:

- **Audio backends.** Android asks for OpenSL first, then AudioTrack, then AAudio:
  libmdk's AAudio output crashes on dispose, stutters on devices with a coarse
  clock and dies on output routing changes, while OpenSL does not.
- **Legacy HEVC FLV.** Streams from the hosts in `legacyHevcFlvHosts` decode in
  software on Android: some hardware HEVC decoders reject codec-id-12 HEVC FLV
  ("Unsupported input buffer") without reporting an error, so the engine would
  keep the failing decoder and play audio only. An empty set disables the rule.

## Notes

- **One engine per source.** libmdk resolves the render target size once per
  player and cannot change it later, so every `open` builds a fresh player and
  releases the previous one. Do not hold a `mdk.Player` across sources.
- **Proxy.** `avio.http_proxy` is set from `proxyUrlResolver`. A loopback input
  (a local relay) must resolve to the empty string, or the loopback request goes
  through the proxy too.
- **No frame heartbeat.** libmdk exposes no decoded-frame callback, so
  `supportsVideoFrameProgress` is `false`: the live watchdog must not arm a
  frame-stall timer for this engine. Position is sampled by the adapter, so
  position-based stall detection works.
- **Audio-only** disables the video track and releases the texture; the setting
  is re-applied on every open.
