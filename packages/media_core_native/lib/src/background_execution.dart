import 'package:flutter/foundation.dart' show FlutterError, TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

/// Channel a background-execution session is requested on.
///
/// Kept in sync with the Android/iOS/macOS plugins and the Windows C++ plugin.
const String kBackgroundExecutionChannel = 'media_core_native/background';

/// Keeps a long-running job alive while the app is not in the foreground.
///
/// Recording a stream, or downloading a large one, is work the user asked for
/// and then stopped watching: without this, the platform suspends or kills the
/// process a few seconds after the screen goes off, and the job dies with an
/// FFmpeg exit code that says nothing about why.
///
/// | platform | what a session does |
/// | --- | --- |
/// | Android | starts a foreground service (`dataSync`) with a notification, plus a partial wake lock so the CPU keeps running with the screen off |
/// | iOS | asks for a background task assertion, which buys the transition window rather than unlimited time (see below) |
/// | macOS | keeps the system from idle-sleeping for as long as the session lives |
/// | Windows | `SetThreadExecutionState(ES_SYSTEM_REQUIRED)`: the system stays awake, the display may still turn off |
/// | Linux | ⏳ not implemented (logind `Inhibit`); [acquire] reports null there |
///
/// ### What this cannot do
///
/// iOS suspends a process that has no reason to keep running, and a network
/// recording is not one — the platform's own answer is the `audio` background
/// mode, which only an app that declares it gets, and only while an audio
/// session is active. [acquire] therefore returns a session that covers the
/// app's transition to the background, and the recording module documents the
/// limit rather than pretending otherwise.
///
/// ### Why a session and not a flag
///
/// The two things a job needs — "somebody has to keep this process running" and
/// "the device must not sleep" — are held by the *platform*, so they have to be
/// released exactly when the job ends. A session object is what makes that
/// release reflexive: `try/finally`, one call, and the notification (or the
/// wake lock) cannot be left behind by a failed path.
final class BackgroundExecution {
  const BackgroundExecution._();

  static const MethodChannel _channel = MethodChannel(kBackgroundExecutionChannel);

  /// Whether this platform implements background execution.
  ///
  /// False on a platform without an implementation, and on a desktop where the
  /// question does not apply the same way. A caller that must know before it
  /// starts the job asks this; a caller that just wants the protection calls
  /// [acquire] and gets null.
  static bool get isSupported {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS || TargetPlatform.windows => true,
      _ => false,
    };
  }

  /// Starts a background-execution session.
  ///
  /// [title] and [text] are what the platform shows while the job runs — on
  /// Android they are a notification the user can see (and tap, which returns
  /// to the app); elsewhere they are ignored.
  ///
  /// [wakeLock] additionally keeps the *CPU* running, which is what matters on
  /// a phone whose screen turned off. A host that only wants the process
  /// permission (a quick upload, a short download) passes false to avoid the
  /// battery cost.
  ///
  /// Returns null when the platform has no implementation, or when the
  /// notification could not be posted (on Android 13+ without
  /// `POST_NOTIFICATIONS` a foreground service has nothing to show). The caller
  /// then runs the job without the protection, which is the honest outcome —
  /// failing the job because the user declined a notification would be worse.
  static Future<BackgroundExecutionSession?> acquire({
    required String title,
    String? text,
    bool wakeLock = true,
  }) async {
    if (!isSupported) {
      return null;
    }

    try {
      final id = await _channel.invokeMethod<int>('acquire', <String, Object?>{
        'title': title,
        'text': text,
        'wakeLock': wakeLock,
      });

      if (id == null) {
        return null;
      }

      return BackgroundExecutionSession._(id);
    } on PlatformException {
      // The native side refused: no permission, no service, a platform that
      // declares support and then does not deliver it. The job still runs.
      return null;
    } on MissingPluginException {
      return null;
    } on FlutterError {
      // Reached without a platform binding: a pure-Dart test, a CLI, an
      // isolate. There is no notification to post and nothing to report.
      return null;
    }
  }

}

/// A held background-execution session.
///
/// An interface rather than only a concrete class because it is the seam a
/// caller holds: a job that must prove it released its session — a test, or a
/// host with its own implementation on a platform this package does not cover —
/// provides its own instead of reaching for the platform.
abstract interface class BackgroundExecutionLease {
  /// Identifier the platform issued for this session.
  int get id;

  /// Whether the session is still held.
  bool get isActive;

  /// Ends the session. Idempotent.
  Future<void> release();
}

/// One running session.
///
/// [release] is idempotent: a job that ends twice (a stop after an exit, a
/// dispose after a stop) must not release somebody else's session.
final class BackgroundExecutionSession implements BackgroundExecutionLease {
  BackgroundExecutionSession._(this.id);

  @override
  final int id;

  bool _released = false;

  /// Whether the session is still held.
  @override
  bool get isActive => !_released;

  /// Ends the session: the notification goes away and the wake lock is freed.
  @override
  Future<void> release() async {
    if (_released) {
      return;
    }

    _released = true;

    try {
      await BackgroundExecution._channel.invokeMethod<void>('release', <String, Object?>{'id': id});
    } on PlatformException {
      // A platform that already tore the session down (process death, service
      // killed) is a released session.
    } on MissingPluginException {
      // Same: nothing to release.
    }
  }

  @override
  String toString() => 'BackgroundExecutionSession(id: $id, active: $isActive)';
}
