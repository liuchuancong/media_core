import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';

/// Minimal [PlayerAdapterBase] implementation exposing the protected
/// emit helpers the contract tests exercise.
final class _TestAdapter extends PlayerAdapterBase {
  _TestAdapter({super.capabilities});

  final List<bool> audioOnlyCommands = <bool>[];

  /// Public mirror of the protected [audioOnly] flag.
  bool get mirroredAudioOnly => audioOnly;

  void reportSize(int width, int height) => emitVideoSizeChanged(width, height);

  void reportFrame() => emitVideoFrameProgress();

  @override
  Future<void> onInitialize(PlayerAdapterContext context) async {}

  @override
  Future<void> onOpen(PlayerSource source) async {}

  @override
  Future<void> onPlay() async {}

  @override
  Future<void> onPause() async {}

  @override
  Future<void> onStop() async {}

  @override
  Future<void> onSeek(Duration position) async {}

  @override
  Future<void> onSetVolume(double volume) async {}

  @override
  Future<void> onSetRate(double rate) async {}

  @override
  Future<void> onSetAudioOnly(bool audioOnly) async => audioOnlyCommands.add(audioOnly);

  @override
  Future<void> onClose() async {}

  @override
  Future<void> onDispose() async {}
}

Future<_TestAdapter> _initialized(PlayerAdapterCapabilities capabilities) async {
  final adapter = _TestAdapter(capabilities: capabilities);
  await adapter.initialize(PlayerAdapterContext(playerId: PlayerId.generate(), sessionId: SessionId.generate()));
  await adapter.open(PlayerSource(id: SourceId('test'), uri: Uri.parse('http://example.com/live.m3u8')));
  return adapter;
}

void main() {
  group('video geometry', () {
    test('publishes the signal and enables the video state', () async {
      final adapter = await _initialized(const PlayerAdapterCapabilities(supportsVideoSizeChanged: true));
      final events = <PlayerAdapterEvent>[];
      final subscription = adapter.events.listen(events.add);

      adapter.reportSize(1920, 1080);
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<PlayerAdapterVideoSizeChanged>(), hasLength(1));
      expect(adapter.state.videoEnabled, isTrue);

      await subscription.cancel();
      await adapter.dispose();
    });

    test('enables the video state even when the signal is not declared', () async {
      // An adapter that cannot report geometry may still be decoding
      // video, so the state transition is applied before the contract
      // check: in release builds the event is dropped, but the state is
      // not lost. In debug builds the missing declaration still trips the
      // assertion, which is the producer contract.
      final adapter = await _initialized(const PlayerAdapterCapabilities());

      expect(() => adapter.reportSize(1920, 1080), throwsAssertionError);
      expect(adapter.state.videoEnabled, isTrue);

      await adapter.dispose();
    });
  });

  group('audio-only command', () {
    test('reaches the engine once per change', () async {
      final adapter = await _initialized(const PlayerAdapterCapabilities(supportsAudioOnly: true));

      await adapter.setAudioOnly(true);
      await adapter.setAudioOnly(true);
      await adapter.setAudioOnly(false);

      expect(adapter.audioOnlyCommands, <bool>[true, false]);
      expect(adapter.mirroredAudioOnly, isFalse);

      await adapter.dispose();
    });

    test('is a contract violation without the capability', () async {
      final adapter = await _initialized(const PlayerAdapterCapabilities());

      expect(() => adapter.setAudioOnly(true), throwsAssertionError);

      await adapter.dispose();
    });
  });
}
