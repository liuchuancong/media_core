import 'dart:async';

import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_pip/media_core_pip.dart';

final class _FakePipWindow implements PipWindow {
  Rect bounds = const Rect.fromLTWH(100, 100, 1280, 720);
  bool alwaysOnTop = false;
  bool resizable = true;
  bool skipTaskbar = false;
  String title = 'Pure Live';

  int captureCount = 0;
  int restoreCount = 0;
  Size? lastSize;
  Offset? lastPosition;
  double? lastAspectRatio;
  bool? lastAlwaysOnTop;
  bool? lastResizable;

  @override
  Future<PipWindowSnapshot> capture() async {
    captureCount++;
    return PipWindowSnapshot(
      bounds: bounds,
      alwaysOnTop: alwaysOnTop,
      resizable: resizable,
      skipTaskbar: skipTaskbar,
      title: title,
    );
  }

  @override
  Future<void> applySmallWindow({
    required Size size,
    required Offset position,
    required double? aspectRatio,
    required bool alwaysOnTop,
    required bool resizable,
    required bool skipTaskbar,
    required String title,
  }) async {
    lastSize = size;
    lastPosition = position;
    lastAspectRatio = aspectRatio;
    lastAlwaysOnTop = alwaysOnTop;
    lastResizable = resizable;
  }

  @override
  Future<void> restore(PipWindowSnapshot snapshot) async {
    restoreCount++;
  }
}

final class _FakeSystemPip implements SystemPip {
  bool available = true;
  SystemPipStatus enableResult = SystemPipStatus.enabled;
  Object? enableError;

  int enableCount = 0;
  int disposeCount = 0;
  int? lastWidth;
  int? lastHeight;
  SystemPipSourceRect? lastSourceRect;

  final StreamController<SystemPipStatus> _statusController = StreamController<SystemPipStatus>.broadcast();

  void emitStatus(SystemPipStatus status) => _statusController.add(status);

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<SystemPipStatus> get status async => SystemPipStatus.disabled;

  @override
  Stream<SystemPipStatus> get statusStream => _statusController.stream;

  @override
  Future<SystemPipStatus> enable({
    required int width,
    required int height,
    SystemPipSourceRect? sourceRect,
    SystemPipTrigger trigger = SystemPipTrigger.immediate,
  }) async {
    enableCount++;
    lastWidth = width;
    lastHeight = height;
    lastSourceRect = sourceRect;
    final error = enableError;
    if (error != null) throw error;
    return enableResult;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _statusController.close();
  }
}

PlayerId _player() => PlayerId('player_pip');

void main() {
  group('PipDriver on desktop', () {
    late _FakePipWindow window;
    late PipDriver driver;

    setUp(() {
      window = _FakePipWindow();
      driver = PipDriver(platform: PipPlatform.desktop, desktopWindow: window);
    });

    tearDown(() => driver.dispose());

    test('shrinks the window and locks it to the video shape', () async {
      await driver.initialize();
      driver.onVideoSize(1920, 1080);

      await driver.apply(_player(), PresentationRequest.pip());

      expect(window.captureCount, 1);
      expect(window.lastAlwaysOnTop, isTrue);
      expect(window.lastResizable, isFalse);
      expect(window.lastAspectRatio, closeTo(16 / 9, 0.001));
      // Landscape video: wide window, height derived from the ratio.
      expect(window.lastSize, const Size(320, 180));
      expect(driver.isPip, isTrue);
    });

    test('sizes a portrait stream with a tall window', () async {
      await driver.initialize();
      driver.onVideoSize(1080, 1920);

      await driver.apply(_player(), PresentationRequest.pip());

      expect(window.lastSize, const Size(180, 320));
      expect(window.lastAspectRatio, closeTo(1080 / 1920, 0.001));
    });

    test('can leave the window unlocked for a fixed-shape small window', () async {
      final unlocked = PipDriver(
        platform: PipPlatform.desktop,
        desktopWindow: window,
        config: PipConfig.defaults.copyWith(lockAspectRatio: false),
      );
      addTearDown(unlocked.dispose);

      await unlocked.initialize();
      unlocked.onVideoSize(1080, 1920);
      await unlocked.apply(_player(), PresentationRequest.pip());

      expect(window.lastAspectRatio, isNull, reason: 'the video is fitted into the window instead of shaping it');
    });

    test('falls back to the configured size when the video size is unknown', () async {
      await driver.initialize();

      await driver.apply(_player(), PresentationRequest.pip());

      expect(window.lastSize, const Size(320, 180));
      expect(window.lastAspectRatio, isNull);
    });

    test('snaps into the bottom-right corner of the previous bounds', () async {
      await driver.initialize();
      driver.onVideoSize(1920, 1080);

      await driver.apply(_player(), PresentationRequest.pip());

      // 100 + 1280 - 320 - 16 = 1044, 100 + 720 - 180 - 16 = 624
      expect(window.lastPosition, const Offset(1044, 624));
    });

    test('leaving PiP restores the captured window state', () async {
      await driver.initialize();
      await driver.apply(_player(), PresentationRequest.pip());

      await driver.apply(_player(), PresentationRequest.normal());

      expect(window.restoreCount, 1);
      expect(driver.isPip, isFalse);
    });

    test('does not restore when restoreWindowOnExit is off', () async {
      final custom = PipDriver(
        platform: PipPlatform.desktop,
        desktopWindow: window,
        config: PipConfig.defaults.copyWith(restoreWindowOnExit: false),
      );
      addTearDown(custom.dispose);

      await custom.initialize();
      await custom.apply(_player(), PresentationRequest.pip());
      await custom.apply(_player(), PresentationRequest.normal());

      expect(window.restoreCount, 0);
      expect(custom.isPip, isFalse);
    });

    test('repeating the request does not capture the window twice', () async {
      await driver.initialize();
      await driver.apply(_player(), PresentationRequest.pip());
      await driver.apply(_player(), PresentationRequest.pip());

      expect(window.captureCount, 1);
    });

    test('refuses modes another driver owns', () async {
      await driver.initialize();

      await expectLater(
        driver.apply(_player(), PresentationRequest.fullscreen()),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        driver.apply(_player(), PresentationRequest.windowFullscreen()),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        driver.apply(_player(), PresentationRequest.floating()),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('reports a stable state stream', () async {
      await driver.initialize();
      final reported = <bool>[];
      driver.onPipChanged.listen(reported.add);

      await driver.apply(_player(), PresentationRequest.pip());
      await driver.apply(_player(), PresentationRequest.normal());
      // The state stream delivers asynchronously.
      await Future<void>.delayed(Duration.zero);

      expect(reported, <bool>[true, false]);
    });
  });

  group('PipDriver on mobile', () {
    late _FakeSystemPip systemPip;
    late PipDriver driver;

    setUp(() {
      systemPip = _FakeSystemPip();
      driver = PipDriver(platform: PipPlatform.mobile, systemPip: systemPip);
    });

    tearDown(() => driver.dispose());

    test('requests the platform with the video size and the source hint', () async {
      await driver.initialize();
      driver.onVideoSize(1280, 720);
      driver.onVideoRect(const Rect.fromLTWH(10, 20, 640, 360));

      await driver.apply(_player(), PresentationRequest.pip());

      expect(systemPip.enableCount, 1);
      expect(systemPip.lastWidth, 1280);
      expect(systemPip.lastHeight, 720);
      expect(systemPip.lastSourceRect?.width, 640);
      expect(driver.isPip, isTrue);
    });

    test('omits the source hint when the feature is configured off', () async {
      final custom = PipDriver(
        platform: PipPlatform.mobile,
        systemPip: systemPip,
        config: PipConfig.defaults.copyWith(requestSourceRectHint: false),
      );
      addTearDown(custom.dispose);

      await custom.initialize();
      custom.onVideoSize(1280, 720);
      custom.onVideoRect(const Rect.fromLTWH(10, 20, 640, 360));

      await custom.apply(_player(), PresentationRequest.pip());

      expect(systemPip.lastSourceRect, isNull);
    });

    test('refuses PiP before a video size is known', () async {
      await driver.initialize();

      await expectLater(
        driver.apply(_player(), PresentationRequest.pip()),
        throwsA(isA<StateError>()),
      );
      expect(systemPip.enableCount, 0);
    });

    test('refuses PiP when the device cannot present it', () async {
      systemPip.available = false;
      await driver.initialize();
      driver.onVideoSize(1280, 720);

      await expectLater(
        driver.apply(_player(), PresentationRequest.pip()),
        throwsA(isA<UnsupportedError>()),
      );
      expect(driver.isPip, isFalse);
    });

    test('refuses PiP when the platform answers unavailable', () async {
      systemPip.enableResult = SystemPipStatus.unavailable;
      await driver.initialize();
      driver.onVideoSize(1280, 720);

      await expectLater(
        driver.apply(_player(), PresentationRequest.pip()),
        throwsA(isA<UnsupportedError>()),
      );
      expect(driver.isPip, isFalse);
    });

    test('a system-initiated exit flips the reported state', () async {
      await driver.initialize();
      driver.onVideoSize(1280, 720);
      final reported = <bool>[];
      driver.onPipChanged.listen(reported.add);

      await driver.apply(_player(), PresentationRequest.pip());
      systemPip.emitStatus(SystemPipStatus.disabled);
      await Future<void>.delayed(Duration.zero);

      expect(driver.isPip, isFalse);
      expect(reported, <bool>[true, false]);
    });

    test('normal cannot exit the system window and does not claim it did', () async {
      await driver.initialize();
      driver.onVideoSize(1280, 720);
      await driver.apply(_player(), PresentationRequest.pip());

      await driver.apply(_player(), PresentationRequest.normal());

      expect(driver.isPip, isTrue);
      expect(systemPip.disposeCount, 0);
    });
  });

  group('PipDriver on an unsupported platform', () {
    test('is unavailable and refuses to enter', () async {
      final driver = PipDriver(platform: PipPlatform.unsupported);
      addTearDown(driver.dispose);

      await driver.initialize();

      expect(await driver.isAvailable, isFalse);
      await expectLater(
        driver.apply(_player(), PresentationRequest.pip()),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
