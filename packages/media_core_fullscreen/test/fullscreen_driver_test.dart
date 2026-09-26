import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_fullscreen/media_core_fullscreen.dart';

final class _FakeFullscreenWindow implements FullscreenWindow {
  Rect bounds = const Rect.fromLTWH(20, 40, 1280, 720);
  bool fullscreen = false;

  int captureCount = 0;
  int setCount = 0;
  Rect? lastRestoreBounds;

  @override
  Future<bool> get isFullscreen async => fullscreen;

  @override
  Future<Rect> captureBounds() async {
    captureCount++;
    return bounds;
  }

  @override
  Future<void> setFullscreen(bool value, {Rect? restoreBounds}) async {
    setCount++;
    fullscreen = value;
    lastRestoreBounds = restoreBounds;
  }
}

PlayerId _player() => PlayerId('player_fullscreen');

void main() {
  group('FullscreenDriver platform fullscreen', () {
    late _FakeFullscreenWindow window;
    late FullscreenDriver driver;

    setUp(() {
      window = _FakeFullscreenWindow();
      driver = FullscreenDriver(platform: FullscreenPlatform.desktop, desktopWindow: window);
    });

    tearDown(() => driver.dispose());

    test('captures the bounds and makes the window fullscreen', () async {
      await driver.initialize();

      await driver.apply(_player(), PresentationRequest.fullscreen());

      expect(window.captureCount, 1);
      expect(window.fullscreen, isTrue);
      expect(driver.isSystemFullscreen, isTrue);
      expect(driver.isAnyFullscreen, isTrue);
    });

    test('leaving restores the captured bounds', () async {
      await driver.initialize();
      await driver.apply(_player(), PresentationRequest.fullscreen());

      await driver.apply(_player(), PresentationRequest.normal());

      expect(window.fullscreen, isFalse);
      expect(window.lastRestoreBounds, const Rect.fromLTWH(20, 40, 1280, 720));
      expect(driver.isSystemFullscreen, isFalse);
    });

    test('does not restore bounds when the feature is configured off', () async {
      final custom = FullscreenDriver(
        platform: FullscreenPlatform.desktop,
        desktopWindow: window,
        config: FullscreenConfig.defaults.copyWith(restorePreviousBounds: false),
      );
      addTearDown(custom.dispose);

      await custom.initialize();
      await custom.apply(_player(), PresentationRequest.fullscreen());
      await custom.apply(_player(), PresentationRequest.normal());

      expect(window.captureCount, 0);
      expect(window.lastRestoreBounds, isNull);
    });

    test('repeating the request does not touch the window twice', () async {
      await driver.initialize();
      await driver.apply(_player(), PresentationRequest.fullscreen());
      await driver.apply(_player(), PresentationRequest.fullscreen());

      expect(window.captureCount, 1);
      expect(window.setCount, 1);
    });

    test('dispose leaves the platform state behind', () async {
      final local = FullscreenDriver(platform: FullscreenPlatform.desktop, desktopWindow: window);
      await local.initialize();
      await local.apply(_player(), PresentationRequest.fullscreen());

      await local.dispose();

      expect(window.fullscreen, isFalse);
    });
  });

  group('FullscreenDriver window fullscreen', () {
    late _FakeFullscreenWindow window;
    late FullscreenDriver driver;

    setUp(() {
      window = _FakeFullscreenWindow();
      driver = FullscreenDriver(platform: FullscreenPlatform.desktop, desktopWindow: window);
    });

    tearDown(() => driver.dispose());

    test('makes no platform call', () async {
      await driver.initialize();

      await driver.apply(_player(), PresentationRequest.windowFullscreen());

      expect(window.setCount, 0, reason: 'the host draws window fullscreen; there is nothing to set');
      expect(window.captureCount, 0);
      expect(driver.isWindowFullscreen, isTrue);
      expect(driver.isSystemFullscreen, isFalse);
    });

    test('leaves the platform fullscreen state first', () async {
      await driver.initialize();
      await driver.apply(_player(), PresentationRequest.fullscreen());

      await driver.apply(_player(), PresentationRequest.windowFullscreen());

      expect(window.fullscreen, isFalse);
      expect(driver.isSystemFullscreen, isFalse);
      expect(driver.isWindowFullscreen, isTrue);
    });

    test('leaving window fullscreen makes no platform call', () async {
      await driver.initialize();
      await driver.apply(_player(), PresentationRequest.windowFullscreen());
      final callsAfterEnter = window.setCount;

      await driver.apply(_player(), PresentationRequest.normal());

      expect(window.setCount, callsAfterEnter);
      expect(driver.isWindowFullscreen, isFalse);
    });
  });

  group('FullscreenDriver orientation strategies', () {
    test('answers the portrait strategy for portrait video', () async {
      final driver = FullscreenDriver(
        platform: FullscreenPlatform.mobile,
        config: FullscreenConfig.defaults.copyWith(
          portraitStrategy: FullscreenFitStrategy.fill,
          landscapeStrategy: FullscreenFitStrategy.fit,
        ),
      );
      addTearDown(driver.dispose);
      await driver.initialize();

      driver.onVideoSize(1080, 1920);

      expect(driver.orientation, VideoOrientation.portrait);
      expect(driver.strategy, FullscreenFitStrategy.fill);
    });

    test('answers the landscape strategy for landscape video', () async {
      final driver = FullscreenDriver(
        platform: FullscreenPlatform.mobile,
        config: FullscreenConfig.defaults.copyWith(
          portraitStrategy: FullscreenFitStrategy.fill,
          landscapeStrategy: FullscreenFitStrategy.rotate,
        ),
      );
      addTearDown(driver.dispose);
      await driver.initialize();

      driver.onVideoSize(1920, 1080);

      expect(driver.orientation, VideoOrientation.landscape);
      expect(driver.strategy, FullscreenFitStrategy.rotate);
    });

    test('falls back to the configured orientation before any video size', () async {
      final driver = FullscreenDriver(
        platform: FullscreenPlatform.mobile,
        config: FullscreenConfig.defaults.copyWith(fallbackOrientation: VideoOrientation.portrait),
      );
      addTearDown(driver.dispose);
      await driver.initialize();

      expect(driver.orientation, VideoOrientation.portrait);
      expect(driver.strategy, FullscreenConfig.defaults.portraitStrategy);
    });

    test('mobile fullscreen is tracked without a platform call', () async {
      final driver = FullscreenDriver(platform: FullscreenPlatform.mobile);
      addTearDown(driver.dispose);
      await driver.initialize();

      await driver.apply(_player(), PresentationRequest.fullscreen());

      expect(driver.isSystemFullscreen, isTrue, reason: 'the host hides the system UI; the mode is still tracked');
    });
  });

  group('FullscreenDriver refusals', () {
    test('refuses modes another driver owns', () async {
      final driver = FullscreenDriver(platform: FullscreenPlatform.desktop, desktopWindow: _FakeFullscreenWindow());
      addTearDown(driver.dispose);
      await driver.initialize();

      for (final request in <PresentationRequest>[PresentationRequest.pip(), PresentationRequest.floating()]) {
        await expectLater(driver.apply(_player(), request), throwsA(isA<UnsupportedError>()));
      }
    });

    test('an unsupported platform refuses both variants', () async {
      final driver = FullscreenDriver(platform: FullscreenPlatform.unsupported);
      addTearDown(driver.dispose);
      await driver.initialize();

      await expectLater(
        driver.apply(_player(), PresentationRequest.fullscreen()),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        driver.apply(_player(), PresentationRequest.windowFullscreen()),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('a disposed driver refuses further requests', () async {
      final driver = FullscreenDriver(platform: FullscreenPlatform.desktop, desktopWindow: _FakeFullscreenWindow());
      await driver.initialize();
      await driver.dispose();

      await expectLater(
        driver.apply(_player(), PresentationRequest.fullscreen()),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('FullscreenDriver state stream', () {
    test('reports both variants and their exits', () async {
      final driver = FullscreenDriver(platform: FullscreenPlatform.desktop, desktopWindow: _FakeFullscreenWindow());
      addTearDown(driver.dispose);
      await driver.initialize();
      final reported = <bool>[];
      driver.onFullscreenChanged.listen(reported.add);

      await driver.apply(_player(), PresentationRequest.fullscreen());
      await driver.apply(_player(), PresentationRequest.windowFullscreen());
      await driver.apply(_player(), PresentationRequest.normal());
      await Future<void>.delayed(Duration.zero);

      // Entered, handed over to the other variant (still fullscreen, so no
      // second event), left entirely. The hand-off deliberately does not
      // report the instant when neither variant was set.
      expect(reported, <bool>[true, false]);
    });
  });
}
