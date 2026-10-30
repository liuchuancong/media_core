import 'package:media_core/media_core.dart';
import 'package:media_core_mpv_audio/src/mpv_audio_adapter.dart';

import 'package:mpv_audio_kit/mpv_audio_kit.dart' as mak;

/// Backend id the mpv_audio adapter registers under, and the id its
/// factory answers to.
const String kMpvAudioBackendId = MpvAudioPlayerAdapter.kMpvAudioBackendId;

/// [PlayerAdapterFactory] that creates [MpvAudioPlayerAdapter] instances.
final class MpvAudioAdapterFactory implements PlayerAdapterFactory {
  /// [capabilities] and the native configuration field are shared by
  /// every adapter this factory creates. [configure] runs once per
  /// instance after construction for per-instance customisation.
  const MpvAudioAdapterFactory({
    this.capabilities = MpvAudioPlayerAdapter.defaultCapabilities,
    this.configuration,
    this.configure,
  });

  /// Capability set every adapter this factory creates reports.
  final PlayerAdapterCapabilities capabilities;

  /// Player-level configuration handed to every created adapter.
  final mak.PlayerConfiguration? configuration;

  /// Runs once per adapter after construction, for per-instance
  /// customisation.
  final void Function(MpvAudioPlayerAdapter adapter)? configure;

  @override
  PlayerAdapter create(String id) {
    final adapter = MpvAudioPlayerAdapter(
      id: id,
      capabilities: capabilities,
      configuration: configuration,
    );
    configure?.call(adapter);
    return adapter;
  }

  @override
  bool supports(String id) => id == kMpvAudioBackendId;

  /// Builds a registration entry for `PlayerKernel.registerBackend` or
  /// a [PlayerAdapterRegistry]. That path carries [capabilities] on the
  /// registration entry itself, so capability-based selection works
  /// before an adapter is ever instantiated.
  PlayerAdapterRegistration registration({int priority = 80}) {
    return PlayerAdapterRegistration(
      id: kMpvAudioBackendId,
      factory: this,
      capabilities: capabilities,
      priority: priority,
    );
  }
}
