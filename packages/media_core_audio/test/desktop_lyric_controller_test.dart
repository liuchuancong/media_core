import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core/testing.dart';
import 'package:media_core_audio/media_core_audio.dart';

/// A source that streams a test URL; the queue path needs one to open a player.
final class _StreamSource extends MusicSource {
  @override
  String get id => 'test';

  @override
  String get name => 'Test';

  @override
  Future<TrackSource> resolveTrackSource(MusicTrack track, {MusicQuality? quality}) async {
    return TrackSource(uri: Uri.parse('https://example.com/${track.id}.m4a'));
  }
}

/// An overlay that records what the controller asked of it and can play the
/// viewer's own buttons back.
final class _FakeTransport implements DesktopLyricTransport {
  final StreamController<DesktopLyricAction> _actions = StreamController<DesktopLyricAction>.broadcast();

  bool shown = false;
  bool disposed = false;
  final List<DesktopLyricState> states = <DesktopLyricState>[];
  final List<({double momentary, double shortTerm, bool active})> levels = <({double momentary, double shortTerm, bool active})>[];

  @override
  Stream<DesktopLyricAction> get actions => _actions.stream;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<bool> show() async {
    shown = true;

    return true;
  }

  @override
  Future<void> hide() async {
    shown = false;
  }

  @override
  Future<void> update(DesktopLyricState state) async {
    states.add(state);
  }

  @override
  Future<void> setLevels({required double momentary, required double shortTerm, required bool active}) async {
    levels.add((momentary: momentary, shortTerm: shortTerm, active: active));
  }

  @override
  Future<void> dispose() async {
    disposed = true;

    await _actions.close();
  }
}

Future<AudioPlaybackController> _player() async {
  final kernel = PlayerKernel()
    ..registerBackend(
      PlayerAdapterRegistration(
        id: 'fake',
        factory: TestPlayerFactory.fakeAdapterFactory(),
        capabilities: const FakePlayerAdapterBehavior().capabilities,
      ),
    );

  final player = AudioPlaybackController(kernel, registry: MusicSourceRegistry(<MusicSource>[_StreamSource()]));

  addTearDown(() async {
    await player.dispose();
    await kernel.dispose();
  });

  return player;
}

void main() {
  test('reports show/hide and lock changes made from the overlay itself', () async {
    final player = await _player();
    final transport = _FakeTransport();
    final desktop = DesktopLyricController(
      player,
      transport: transport,
      permissions: AudioPermissionService(transport: NoopAudioPermissionTransport()),
    );
    addTearDown(desktop.dispose);

    final visible = <bool>[];
    final locked = <bool>[];
    desktop.visibleChanges.listen(visible.add);
    desktop.lockedChanges.listen(locked.add);

    expect(await desktop.show(), isTrue);
    await pumpEventQueue();
    expect(transport.shown, isTrue);
    expect(desktop.visible, isTrue);
    expect(visible, <bool>[true]);

    transport._actions.add(DesktopLyricAction.close);
    await pumpEventQueue();
    expect(desktop.visible, isFalse);
    expect(transport.shown, isFalse);
    expect(visible, <bool>[true, false]);

    transport._actions.add(DesktopLyricAction.lock);
    await pumpEventQueue();
    expect(desktop.locked, isTrue);
    expect(locked, <bool>[true]);

    transport._actions.add(DesktopLyricAction.unlock);
    await pumpEventQueue();
    expect(desktop.locked, isFalse);
    expect(locked, <bool>[true, false]);
  });
}
