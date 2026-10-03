import 'package:flutter_test/flutter_test.dart';

import 'package:media_core/media_core.dart';
import 'package:media_core/testing/fake_player_adapter.dart';

import 'package:media_core_live/media_core_live.dart';

/// Hands out one specific fake per engine id so a test can read back what
/// that engine was asked to do.
final class _EngineFactory implements PlayerAdapterFactory {
  _EngineFactory(this.adapters);

  final Map<String, FakePlayerAdapter> adapters;

  @override
  PlayerAdapter create(String id) => adapters[id] ?? (throw StateError('no fake for $id'));

  @override
  bool supports(String id) => adapters.containsKey(id);
}

FakePlayerAdapter _fake(String id, {Set<String> failOn = const {}}) {
  return FakePlayerAdapter(
    id: id,
    behavior: FakePlayerAdapterBehavior(
      failOn: failOn,
      openDuration: const Duration(minutes: 3),
    ),
  );
}

PlayerKernel _kernel(Map<String, FakePlayerAdapter> adapters) {
  final kernel = PlayerKernel();
  for (final entry in adapters.entries) {
    kernel.registerBackend(
      PlayerAdapterRegistration(
        id: entry.key,
        factory: _EngineFactory(adapters),
        capabilities: FakePlayerAdapterBehavior.defaultCapabilities,
        priority: 10,
      ),
    );
  }
  return kernel;
}

PlayerSource _line(String url, {String? title}) {
  final uri = Uri.parse(url);
  return PlayerSource(
    id: SourceId(url),
    uri: uri,
    type: SourceType.live,
    protocol: SourceProtocol.fromScheme(uri.scheme),
    mediaType: SourceMediaType.video,
    format: SourceFormat.fromUri(uri),
    title: title,
  );
}

LiveSourceRequest _request(List<String> urls, {bool? allowEngineFallback}) {
  return LiveSourceRequest(
    sources: urls.map((url) => _line(url)).toList(growable: false),
    allowEngineFallback: allowEngineFallback,
  );
}

/// Watchdogs off: these tests drive the sweep, and a stall detector firing in
/// the middle of one would make the assertion about the wrong decision.
LivePlaybackController _controller(PlayerKernel kernel) {
  return LivePlaybackController(
    kernel,
    watchdogs: LiveWatchdogs(enabled: false),
  );
}

void main() {
  group('LivePlaybackController.play', () {
    test('a stream that never advances is refused, not adopted', () async {
      // The whole point of the sweep: opening is not playing. A backend that
      // accepts the URL and then produces no position progress must be
      // abandoned, and the caller must hear about it exactly once.
      final adapters = {'engine-a': _fake('engine-a')};
      final kernel = _kernel(adapters);
      final controller = _controller(kernel);

      final failures = <PlayerFailure>[];
      final subscription = controller.onError.listen(failures.add);

      await controller.play(
        _request(['https://a.example/live.flv'], allowEngineFallback: false),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(failures, hasLength(1));
      expect(failures.single.code, PlayerErrorCode.noPlayableStream);
      expect(failures.single.message, contains('https://a.example/live.flv'));
      expect(adapters['engine-a']!.calls, contains('open'));

      await subscription.cancel();
      await controller.dispose();
      await kernel.dispose();
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('an engine that cannot open is escalated to the next one', () async {
      final adapters = {
        'engine-a': _fake('engine-a', failOn: const {'open'}),
        'engine-b': _fake('engine-b'),
      };
      final kernel = _kernel(adapters);
      final controller = _controller(kernel);

      final failures = <PlayerFailure>[];
      final subscription = controller.onError.listen(failures.add);

      final playing = controller.play(_request(['https://a.example/live.flv']));

      // Feed the second engine a progressing position so verification ends;
      // without it the sweep would sit out the whole window on every engine.
      await _pumpPosition(adapters.values);
      await playing;

      expect(adapters['engine-a']!.calls, contains('open'));
      expect(adapters['engine-b']!.calls, contains('open'));
      expect(controller.backendId, 'engine-b');
      expect(failures, isEmpty);

      await subscription.cancel();
      await controller.dispose();
      await kernel.dispose();
    }, timeout: const Timeout(Duration(seconds: 40)));

    test('refusing engine fallback stops at the first engine', () async {
      final adapters = {
        'engine-a': _fake('engine-a', failOn: const {'open'}),
        'engine-b': _fake('engine-b'),
      };
      final kernel = _kernel(adapters);
      final controller = _controller(kernel);

      final failures = <PlayerFailure>[];
      final subscription = controller.onError.listen(failures.add);

      await controller.play(
        _request(['https://a.example/live.flv'], allowEngineFallback: false),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(adapters['engine-a']!.calls, contains('open'));
      expect(
        adapters['engine-b']!.calls,
        isNot(contains('open')),
        reason: 'the caller declined escalation, so the second engine must '
            'never be touched',
      );
      expect(failures, hasLength(1));
      expect(failures.single.code, PlayerErrorCode.noPlayableStream);

      await subscription.cancel();
      await controller.dispose();
      await kernel.dispose();
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('a line that plays is kept, and the alternatives are not tried', () async {
      // The sweep is a ladder, not a lottery: once a line proves it is
      // advancing, the remaining candidates must stay untouched, because
      // opening a second live line costs a second stream nobody watches.
      final adapters = {'engine-a': _fake('engine-a')};
      final kernel = _kernel(adapters);
      final controller = _controller(kernel);

      final playing = controller.play(
        _request(['https://first.example/live.flv', 'https://second.example/live.flv']),
      );
      await _pumpPosition(adapters.values);
      await playing;

      final opened = adapters['engine-a']!.openedSources;
      expect(opened, hasLength(1));
      expect(opened.single.uri.host, 'first.example');
      expect(controller.sourceIndex, 0);

      await controller.dispose();
      await kernel.dispose();
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('LivePlaybackController lifecycle', () {
    test('close releases the handle and returns the session to idle', () async {
      final adapters = {'engine-a': _fake('engine-a')};
      final kernel = _kernel(adapters);
      final controller = _controller(kernel);

      final states = <PlayerCoreState>[];
      final subscription = controller.onStateChanged.listen(states.add);

      final playing = controller.play(_request(['https://a.example/live.flv']));
      await _pumpPosition(adapters.values);
      await playing;

      expect(controller.handle, isNotNull);

      await controller.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.handle, isNull);
      expect(states.last, PlayerCoreState.idle);

      await subscription.cancel();
      await controller.dispose();
      await kernel.dispose();
    }, timeout: const Timeout(Duration(seconds: 40)));

    test('a disposed controller never starts playback again', () async {
      final adapters = {'engine-a': _fake('engine-a')};
      final kernel = _kernel(adapters);
      final controller = _controller(kernel);

      await controller.dispose();

      // Whether this refuses quietly or throws is the controller's choice;
      // the invariant a caller depends on is that no engine is opened and no
      // handle comes back.
      Object? thrown;
      try {
        await controller.play(_request(['https://a.example/live.flv']));
      } catch (error) {
        thrown = error;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(adapters['engine-a']!.calls, isNot(contains('open')));
      expect(controller.handle, isNull);
      expect(thrown, anyOf(isNull, isA<StateError>()), reason: 'refusal must be quiet or explicit, not a half-started session');

      await kernel.dispose();
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('state changes are published for the caller to render', () async {
      final adapters = {'engine-a': _fake('engine-a')};
      final kernel = _kernel(adapters);
      final controller = _controller(kernel);

      final states = <PlayerCoreState>[];
      final subscription = controller.onStateChanged.listen(states.add);

      final playing = controller.play(_request(['https://a.example/live.flv']));
      await _pumpPosition(adapters.values);
      await playing;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, isNotEmpty);

      await subscription.cancel();
      await controller.dispose();
      await kernel.dispose();
    }, timeout: const Timeout(Duration(seconds: 40)));
  });
}

/// Drives the mirror's position forward while a sweep is verifying.
///
/// The fake adapter only reports a position when it is asked to seek, so this
/// stands in for a stream that is actually advancing. It seeks the adapters
/// rather than `controller.handle`, because the handle is only published once
/// verification has already passed — during the sweep it is still staged.
/// Verification polls every 250 ms inside an 8 s window, which this covers.
Future<void> _pumpPosition(
  Iterable<FakePlayerAdapter> adapters, {
  Duration window = const Duration(seconds: 4),
}) async {
  final deadline = DateTime.now().add(window);
  var position = const Duration(seconds: 1);

  while (DateTime.now().isBefore(deadline)) {
    for (final adapter in adapters) {
      try {
        await adapter.seek(position);
      } catch (_) {
        // An adapter that failed to open has nothing to seek; the sweep is
        // about to move past it anyway.
      }
    }
    position += const Duration(seconds: 1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
