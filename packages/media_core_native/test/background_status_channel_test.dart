// Its own file because the platform watch is one subscription for the process:
// whatever reaches it first decides what every later test sees. Here nothing runs
// before these two assertions, so each one starts from a watch nobody has taken.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_native/media_core_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only Android is asked for the status channel', () async {
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

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final desktop = BackgroundExecution.sessionStatuses.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    expect(asks, isEmpty);
    await desktop.cancel();

    // `flutter test` reports Android as the target whatever the host is, which is
    // also what the first half of this test would have needed an override for.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final android = BackgroundExecution.sessionStatuses.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    expect(asks, ['listen'], reason: 'the one platform with a service that can be stopped is the one asked');
    await android.cancel();

    messenger.setMockMethodCallHandler(statusChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });
}
