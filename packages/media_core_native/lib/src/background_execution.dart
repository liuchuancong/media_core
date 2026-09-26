import 'package:flutter/foundation.dart' show FlutterError, TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

/// Channel a background-execution session is requested on.
///
/// Kept in sync with the Android/iOS/macOS plugins and the Windows C++ plugin.
const String kBackgroundExecutionChannel = 'media_core_native/background';

/// What a session is doing, for the notification that shows it.
///
/// Android is the platform that shows one, and an icon is the half of a
/// notification a user reads before the text — a download arrow on a recording
/// is a small lie, so the kind is asked for instead of assumed.
enum BackgroundJobKind {
  /// Capturing a stream to disk.
  record,

  /// Fetching a file.
  download,

  /// Anything else: the generic glyph.
  task,
}

/// Keeps a long-running job alive while the app is not in the foreground.
///
/// Recording a stream, or downloading a large one, is work the user asked for
/// and then stopped watching: without this, the platform suspends or kills the
/// process a few seconds after the screen goes off, and the job dies with an
/// FFmpeg exit code that says nothing about why.
///
/// | platform | what a session does |
/// | --- | --- |
/// | Android | starts a foreground service (`dataSync`) with a notification the user can see (and tap, which returns to the app), plus a partial wake lock so the CPU keeps running with the screen off |
/// | iOS | asks for a background task assertion, which buys the transition window rather than unlimited time (see below) |
/// | macOS | keeps the system from idle-sleeping for as long as the session lives |
/// | Windows | `SetThreadExecutionState(ES_SYSTEM_REQUIRED)`: the system stays awake, the display may still turn off |
/// | Linux | ⏳ not implemented (logind `Inhibit`); [acquire] reports null there |
///
/// ### The Android notification permission
///
/// From Android 13 a foreground service shows its notification only with
/// `POST_NOTIFICATIONS`. The plugin declares it and asks for it on the first
/// [acquire] that needs it, while an activity is attached, so a host does not
/// have to know this step exists. A refusal is not a failure: the service and
/// the wake lock still hold — the user simply sees no notification, which is
/// their choice rather than something to fail a recording over.
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
  /// to the app); elsewhere they are ignored. [kind] picks the notification's
  /// icon.
  ///
  /// [wakeLock] additionally keeps the *CPU* running, which is what matters on
  /// a phone whose screen turned off. A host that only wants the process
  /// permission (a quick upload, a short download) passes false to avoid the
  /// battery cost.
  ///
  /// Several sessions can be held at once — on Android they share one service
  /// and one notification, and releasing one leaves the others running, so a
  /// recording and a download do not take each other's protection away.
  ///
  /// Returns null when the platform has no implementation, or when it refuses
  /// to run the service at all. A refused *notification* still returns a
  /// session: the job keeps its protection and only the notification is hidden,
  /// which is the honest outcome — failing a recording because the user
  /// declined a notification would be worse.
  static Future<BackgroundExecutionSession?> acquire({
    required String title,
    String? text,
    bool wakeLock = true,
    BackgroundJobKind kind = BackgroundJobKind.task,
  }) async {
    if (!isSupported) {
      return null;
    }

    try {
      final id = await _channel.invokeMethod<int>('acquire', <String, Object?>{
        'title': title,
        'text': text,
        'wakeLock': wakeLock,
        'kind': kind.name,
      });

      if (id == null) {
        return null;
      }

      return BackgroundExecutionSession._(id);
    } on PlatformException {
      // The native side refused: no service, no declaration, a platform that
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
