// Its own file because the platform watch is one subscription for the process:
// whatever reaches it first decides what every later test sees. Here nothing runs
// before these assertions, so each starts from a watch nobody has taken.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_native/media_core_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the status watch is Android’s, and taken once for the process', () async {
    // The iOS, macOS and Windows handlers implement `acquire` and nothing else, so
    // a `listen` on the status channel is a method they answer as unimplemented —
    // and the SDK reports that as an error on every job started on a machine with
    // no service that could ever be stopped under it.
    const statusChannel = MethodChannel(kBackgroundStatusChannel);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final asks = <String>[];
    messenger.setMockMethodCallHandler(statusChannel, (call) async {
      asks.add(call.method);

      return null;
    });

    // The static watch is process-wide and is never released, so this half comes
    // first: once a test had taken the watch, a later desktop assertion would pass
    // because of the short-circuit rather than because of the platform gate.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final desktop = BackgroundExecution.sessionStatuses.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    expect(asks, isEmpty, reason: 'a desktop handler answers `listen` as unimplemented');
    await desktop.cancel();

    // Named rather than left to the default, because `flutter test` reports Android
    // whatever the host operating system is — the gate is what is being asserted,
    // not the machine the suite happens to run on.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final android = BackgroundExecution.sessionStatuses.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    expect(asks, ['listen'], reason: 'the one platform with a service that can be stopped is the one asked');

    // A second lease asking must not take a second subscription: the Android side
    // keeps one sink list per engine, and a second `listen` on the same channel
    // would replace the first one's handler rather than widen it.
    final alsoAndroid = BackgroundExecution.sessionStatuses.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    expect(asks, ['listen'], reason: 'one subscription for the process, whatever the number of leases');
    await android.cancel();
    await alsoAndroid.cancel();

    messenger.setMockMethodCallHandler(statusChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });
}
