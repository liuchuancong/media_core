import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core/testing/library.dart';

/// Registration whose adapter instances are kept for assertions.
PlayerAdapterRegistration _fakeRegistration({
  required List<FakePlayerAdapter> created,
  FakePlayerAdapterBehavior? behavior,
}) {
  final factory = DefaultPlayerAdapterFactory();
  var counter = 0;

  factory.register('fake', () {
    final adapter = FakePlayerAdapter(id: 'fake-${++counter}', behavior: behavior ?? const FakePlayerAdapterBehavior());
    created.add(adapter);
    return adapter;
  });

  return PlayerAdapterRegistration(
    id: 'fake',
    factory: factory,
    capabilities: (behavior ?? const FakePlayerAdapterBehavior()).capabilities,
    priority: 100,
  );
}

PlayerKernel _kernelWith(PlayerAdapterRegistration registration) {
  return PlayerKernel()..registerBackend(registration);
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('audio-only preference reaches the active adapter', () async {
    final created = <FakePlayerAdapter>[];
    final controller = LivePlaybackController(_kernelWith(_fakeRegistration(created: created)));

    await controller.play(const LiveSourceRequest(urls: <String>['http://example.com/live.m3u8']));

    await controller.setAudioOnly(true);

    expect(controller.audioOnly, isTrue);
    expect(created.single.audioOnlyValues, <bool>[true]);

    // Setting the same value again is not a round trip to the engine.
    await controller.setAudioOnly(true);
    expect(created.single.audioOnlyValues, <bool>[true]);

    await controller.dispose();
  });

  test('audio-only preference survives a rebind on a new adapter', () async {
    final created = <FakePlayerAdapter>[];
    final controller = LivePlaybackController(_kernelWith(_fakeRegistration(created: created)));

    await controller.play(const LiveSourceRequest(urls: <String>['http://example.com/live.m3u8']));

    await controller.setAudioOnly(true);
    expect(created.first.audioOnlyValues, <bool>[true]);

    // Leaving the room and entering the next one builds a fresh adapter.
    await controller.close();
    await _settle();
    await controller.play(const LiveSourceRequest(urls: <String>['http://example.com/other.m3u8']));

    expect(created, hasLength(2));
    expect(created.last.audioOnlyValues, <bool>[true]);

    await controller.dispose();
  });

  test('audio-only is dropped for adapters without the capability', () async {
    final created = <FakePlayerAdapter>[];
    final behavior = FakePlayerAdapterBehavior(
      capabilities: const PlayerAdapterCapabilities(supportsLive: true, supportsAudioOnly: false),
    );
    final controller = LivePlaybackController(
      _kernelWith(_fakeRegistration(created: created, behavior: behavior)),
    );

    await controller.play(const LiveSourceRequest(urls: <String>['http://example.com/live.m3u8']));

    await controller.setAudioOnly(true);

    // The preference is still recorded for the next capable adapter, but
    // this engine is never asked for a track switch it cannot perform.
    expect(controller.audioOnly, isTrue);
    expect(created.single.audioOnlyValues, isEmpty);

    await controller.dispose();
  });
}
