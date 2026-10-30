part of 'player_handle.dart';

/// Audio output device listing.
///
/// Selection is not here on purpose: it rides [applyEngineOptions] as the
/// `audio-device` option like any other engine key, so the handle's option
/// memory keeps the choice across recovery swaps and rebuilds.
extension PlayerHandleAudioDevices on PlayerHandle {
  /// The engine's audio output devices, current one marked; empty when this
  /// backend has no device picker.
  Future<List<PlayerAudioDevice>> listAudioDevices() {
    _ensureNotDisposed();

    return _runtime.adapter.listAudioDevices();
  }
}
