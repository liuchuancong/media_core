// This file uses `package:test`, not `flutter_test`, on purpose.
//
// `flutter_test` initialises a binding before each test, and the case here is the
// one with no binding at all: a pure-Dart isolate, a CLI, a host that asks for
// background execution before `runApp`. The platform side is quiet by construction
// when a binding exists; without one, reaching for the status channel's messenger
// threw inside the stream's detached `onListen` future — a place no caller can
// catch, so the host got an uncaught zone error out of a library that never
// claimed to be standing on a platform. That is what these tests keep quiet.
@TestOn('vm')
library;

import 'package:flutter/foundation.dart';
import 'package:media_core_native/media_core_native.dart';
import 'package:test/test.dart';

void main() {
  // The Android branch, because that is the one that reaches for the channel. Left
  // on a desktop target this file would prove nothing: a desktop is quiet for the
  // platform reason, and the missing binding would never be exercised.
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('asking for a session with no platform answers, it does not throw', () async {
    final attempt = await BackgroundExecution.acquireDetailed(
      notification: const BackgroundNotification(title: 'a room'),
    );

    expect(attempt.session, isNull);
  });

  test('the status view with no platform stays empty', () async {
    final seen = <BackgroundSessionReport>[];
    final subscription = BackgroundExecution.sessionStatuses.listen(seen.add);

    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(seen, isEmpty);
  });
}
