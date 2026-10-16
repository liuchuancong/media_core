import 'dart:async';

import 'package:flutter/foundation.dart'
    show FlutterError, TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';

/// Channel a background-execution session is requested on.
///
/// Kept in sync with the Android/iOS/macOS plugins and the Windows C++ plugin.
const String kBackgroundExecutionChannel = 'media_core_native/background';

/// Channel the platform reports a held session's status back on.
///
/// The way back exists because the two ends can disagree: only the platform knows
/// that it stopped a foreground service when the allowance ran out, or that the
/// notification it holds is invisible because the user never granted
/// `POST_NOTIFICATIONS`. Without it, a Dart-side lease keeps counting protection
/// that has already been taken away.
const String kBackgroundStatusChannel = 'media_core_native/background_status';

/// What the platform said about a session it holds.
///
/// The package's own words, deliberately not `media_core`'s `BackgroundSessionStatus`:
/// this channel is usable from a host that links no core package, and the adapter in
/// `native_background_backend.dart` is where the two vocabularies meet.
enum BackgroundExecutionStatus {
  /// Running, but one of the promises was given up (the line is not visible).
  degraded,

  /// Nothing is held for the session any more.
  stopped,

  /// The platform took the protection back while the job kept running.
  ///
  /// Not `stopped` — nobody released it — and not a failure: the recording is
  /// still recording, it is just no longer exempt from being frozen.
  protectionLost,
}

/// One status report about one session.
///
/// The `id` is the same handle `acquire` returned, so a listener can tell whether the
/// report concerns its own session without asking a second question.
typedef BackgroundSessionReport = ({int id, BackgroundExecutionStatus status});

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
  task;

  /// Which foreground service a session of this kind belongs to by default.
  ///
  /// A default, not a decision: a caller that knows the runtime contract passes an
  /// explicit `target:` to [BackgroundExecution.acquire], and the Android side
  /// routes on that rather than guessing from a glyph name.
  BackgroundServiceTarget get serviceTarget => switch (this) {
    BackgroundJobKind.record => BackgroundServiceTarget.recording,
    BackgroundJobKind.download => BackgroundServiceTarget.download,
    BackgroundJobKind.task => BackgroundServiceTarget.generic,
  };
}

/// Which foreground service holds a session.
///
/// One target means one service, one notification, one wake lock and one
/// platform allowance. Nothing that ends a session of one target — a release, an
/// Android `dataSync` timeout, a notification permission the user declined —
/// reaches another target's sessions, which is the reason this exists: with a
/// single service for everything, a download that outlived its allowance stopped
/// the service a recording was still using.
///
/// The names are the wire spelling of the runtime contract's
/// `BackgroundServiceOwner` (`recording`, `download`, `genericJob` → [generic]);
/// `media_core_native` does not import that type here so the channel stays
/// usable from a host that links no core package.
enum BackgroundServiceTarget {
  /// The recording service: its own line, its own lock, `specialUse` on API 34+.
  recording,

  /// The download service: its own line, its own lock, `dataSync`.
  download,

  /// The catch-all service for work the runtime cannot name.
  generic,
}

/// What a session's notification says, and how far along the job is.
///
/// Every field is what the *host* knows and the platform can only be told: the
/// library ships the mechanism, not the words. Only Android draws a
/// notification today, so on the other platforms this describes something with
/// no visible effect — [BackgroundExecutionSession.update] is then a no-op
/// rather than an error, because the job's protection is the point and the
/// notification is how the user is told about it.
///
/// ```dart
/// final session = await BackgroundExecution.acquire(
///   notification: const BackgroundNotification(
///     title: '正在录制',
///     text: 'room-42 · 00:12:34',
///     kind: BackgroundJobKind.record,
///     progress: BackgroundProgress.indeterminate(),
///   ),
/// );
/// ```
final class BackgroundNotification {
  /// Creates a description of the notification.
  const BackgroundNotification({
    required this.title,
    this.text,
    this.kind = BackgroundJobKind.task,
    this.icon,
    this.progress,
  });

  /// First line: what is running. The host's own words (a room name, a
  /// programme), which is why the library never invents it.
  final String title;

  /// Second line: what it is working on. Null shows a bare title.
  final String? text;

  /// What the job is; [icon] falls back to the glyph shipped for this kind.
  final BackgroundJobKind kind;

  /// Name of a drawable in the **host app's** `res/drawable` — the same
  /// convention the media notification uses (`MediaSessionConfig.playIcon`).
  ///
  /// Null uses the glyph this package ships for [kind]. A name that does not
  /// resolve in the host app also falls back to that glyph, so a missing asset
  /// leaves a plain notification rather than a broken one.
  final String? icon;

  /// Progress to show, or null for none.
  final BackgroundProgress? progress;

  /// Same description with some fields replaced.
  ///
  /// What a long job uses to keep the notification moving (elapsed time, bytes
  /// written, percentage) without holding on to every field it started with:
  /// `session.update(description.copyWith(text: elapsed))`.
  BackgroundNotification copyWith({
    String? title,
    String? text,
    BackgroundJobKind? kind,
    String? icon,
    BackgroundProgress? progress,
  }) {
    return BackgroundNotification(
      title: title ?? this.title,
      text: text ?? this.text,
      kind: kind ?? this.kind,
      icon: icon ?? this.icon,
      progress: progress ?? this.progress,
    );
  }

  @override
  String toString() =>
      'BackgroundNotification(title: $title, text: $text, kind: ${kind.name}, icon: $icon, progress: $progress)';
}

/// How far along a job is, for the platforms that can show it.
///
/// A live recording has no total, which is why indeterminate is a first-class
/// shape and not "0 of 0": a percentage the job cannot know would make the
/// platform draw a bar that means nothing.
final class BackgroundProgress {
  /// The platform draws an activity indicator: the job is running, its end is
  /// not known (a live recording).
  const BackgroundProgress.indeterminate() : current = null, total = null;

  /// The platform draws a filled bar: [current] out of [total] (a download).
  const BackgroundProgress.determinate({required this.current, required this.total})
    : assert(total != null && total > 0, 'total must be a positive count for a determinate bar');

  /// Completed units, or null when the end is unknown.
  final int? current;

  /// Units in total, or null when the end is unknown.
  final int? total;

  /// Whether the end is unknown.
  bool get isIndeterminate => total == null;

  /// Fraction complete in `0..1`, or null when indeterminate.
  double? get fraction => total == null ? null : (current ?? 0) / total!;

  @override
  String toString() => isIndeterminate ? 'BackgroundProgress.indeterminate()' : 'BackgroundProgress($current/$total)';
}

/// Why the channel produced no session.
enum BackgroundExecutionRefusal {
  /// This platform has no implementation to ask.
  unsupportedPlatform,

  /// The platform answered, and the answer was no: the service would not start.
  serviceRefused,

  /// The plugin is not linked into this app.
  pluginMissing,

  /// Nothing to talk to: a pure-Dart test, a CLI, an isolate.
  noPlatformBinding,
}

/// What [BackgroundExecution.acquireDetailed] answered.
///
/// Exactly one side is set: a session when the platform holds the job, a refusal
/// when it does not.
typedef BackgroundExecutionAttempt = ({BackgroundExecutionSession? session, BackgroundExecutionRefusal? refusal});

/// Keeps a long-running job alive while the app is not in the foreground.
///
/// Recording a stream, or downloading a large one, is work the user asked for
/// and then stopped watching: without this, the platform suspends or kills the
/// process a few seconds after the screen goes off, and the job dies with an
/// FFmpeg exit code that says nothing about why.
///
/// | platform | what a session does |
/// | --- | --- |
/// | Android | starts **that target's** foreground service — `specialUse` for recording, `dataSync` for download and generic work — with a notification the user can see (and tap, which returns to the app), plus a partial wake lock so the CPU keeps running with the screen off |
/// | iOS | asks for a background task assertion, which buys the transition window rather than unlimited time (see below) |
/// | macOS | keeps the system from idle-sleeping for as long as the session lives |
/// | Windows | `SetThreadExecutionState(ES_SYSTEM_REQUIRED)`: the system stays awake, the display may still turn off |
/// | Linux | ⏳ not implemented (logind `Inhibit`); [acquire] reports null there |
///
/// ### What the host controls
///
/// The notification is described by a [BackgroundNotification]: title, second
/// line, icon (a drawable of the host's own, or the glyph shipped for the job's
/// [BackgroundJobKind]) and [BackgroundProgress]. It can be replaced at any time
/// through [BackgroundExecutionSession.update] — which is what a long job uses to
/// show elapsed time or a percentage — and it disappears with the session.
///
/// What is deliberately **not** configurable: buttons/actions (a stop button
/// needs a callback path and a wake-up into Dart, which is a feature of its own),
/// and the Android notification channel — one per [BackgroundServiceTarget], so a
/// user can silence downloads while leaving recordings loud, without hunting per
/// job. Media *playback* notifications are a different surface with a different
/// owner: that is `MediaSessionConfig` in `media_core_mediasession`.
///
/// ### The Android notification permission
///
/// From Android 13 a foreground service shows its notification only with
/// `POST_NOTIFICATIONS`. The plugin declares it and never asks for it: when the
/// user is asked is the app's decision, and an acquire that popped a dialog could
/// hold a resumed download hostage to the answer. `MediaCoreNotify.requestPermission()`
/// is the one entry point for the question. A refusal is not a failure: the service
/// and the wake lock still hold — the user simply sees no notification, which is
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
  /// [notification] is what the user sees while the job runs — a notification on
  /// Android (tapping it returns to the app), ignored elsewhere.
  ///
  /// [wakeLock] additionally keeps the *CPU* running, which is what matters on
  /// a phone whose screen turned off. A host that only wants the process
  /// permission (a quick upload, a short download) passes false to avoid the
  /// battery cost.
  ///
  /// Several sessions can be held at once. Within one [BackgroundServiceTarget]
  /// they share that target's service and its one notification — the newest
  /// session supplies the text and the others are counted in its second line —
  /// and releasing one leaves the rest running. Sessions of *different* targets
  /// share nothing at all: different service, different notification, different
  /// wake lock, different platform allowance.
  ///
  /// [target] decides which service holds the session; it defaults to
  /// `notification.kind`'s own target. Pass it explicitly when the session is a
  /// runtime-contract session, so the routing follows the declared owner instead
  /// of a glyph.
  ///
  /// Returns null when the platform has no implementation, or when it refuses
  /// to run the service at all. A refused *notification* still returns a
  /// session: the job keeps its protection and only the notification is hidden,
  /// which is the honest outcome — failing a recording because the user
  /// declined a notification would be worse.
  static Future<BackgroundExecutionSession?> acquire({
    required BackgroundNotification notification,
    BackgroundServiceTarget? target,
    bool wakeLock = true,
  }) async {
    return (await acquireDetailed(notification: notification, target: target, wakeLock: wakeLock)).session;
  }

  /// [acquire], with the reason kept.
  ///
  /// `acquire` answers "do I hold it?" and its null answers every question at
  /// once: no implementation here, the system refused the service, a host that
  /// forgot to link the plugin, a test with no platform binding. A runtime that
  /// has to tell the user which of those happened — or decide whether to retry —
  /// asks this instead.
  static Future<BackgroundExecutionAttempt> acquireDetailed({
    required BackgroundNotification notification,
    BackgroundServiceTarget? target,
    bool wakeLock = true,
  }) async {
    if (!isSupported) {
      return (session: null, refusal: BackgroundExecutionRefusal.unsupportedPlatform);
    }

    try {
      final id = await _channel.invokeMethod<int>('acquire', <String, Object?>{
        'notification': encodeNotification(notification),
        // Which service holds this session. Sent as text so an older native side
        // that ignores the key still starts a service and the job is protected —
        // it just lands in the catch-all one, which is a worse label, not a failure.
        'owner': (target ?? notification.kind.serviceTarget).name,
        'wakeLock': wakeLock,
      });

      if (id == null) {
        return (session: null, refusal: BackgroundExecutionRefusal.serviceRefused);
      }

      return (session: BackgroundExecutionSession._(id), refusal: null);
    } on PlatformException {
      // The native side refused: no service, no declaration, a platform that
      // declares support and then does not deliver it. The job still runs.
      return (session: null, refusal: BackgroundExecutionRefusal.serviceRefused);
    } on MissingPluginException {
      return (session: null, refusal: BackgroundExecutionRefusal.pluginMissing);
    }
    // FlutterError is reached only when there is no platform binding (a
    // pure-Dart test, a CLI, an isolate); it is caught deliberately so the job
    // degrades to no-op instead of crashing, even though it is an Error.
    // ignore: avoid_catching_errors
    on FlutterError {
      // Reached without a platform binding: a pure-Dart test, a CLI, an
      // isolate. There is no notification to post and nothing to report.
      return (session: null, refusal: BackgroundExecutionRefusal.noPlatformBinding);
    }
  }

  static const EventChannel _statusChannel = EventChannel(kBackgroundStatusChannel);

  /// What the platform reports about sessions it holds.
  ///
  /// Broadcast, and empty wherever nothing reports: a platform with no status
  /// channel (Linux), a test with no binding, or a service that simply never ran
  /// out of allowance.
  ///
  /// One subscription to the platform whatever the number of listeners here, which
  /// is what the Android side assumes (its sink list is per engine, not per lease)
  /// and what makes addressing by handle matter: every lease sees every report and
  /// keeps only its own.
  ///
  /// This is the path that turns `BackgroundBackendLease.statusChanges` from a
  /// placeholder into an answer: a foreground service the system stopped leaves the
  /// Dart registry believing it still holds the exemption and the wake lock, and a
  /// lease that never learns stops counting is how a recording reports itself
  /// protected for the rest of its life.
  static Stream<BackgroundSessionReport> get sessionStatuses {
    _watchPlatform();

    return _statuses.stream;
  }

  static final StreamController<BackgroundSessionReport> _statuses =
      StreamController<BackgroundSessionReport>.broadcast();
  // Never cancelled on purpose: this is the process's one view of the platform's
  // status channel, and tearing it down would silently blind every lease that still
  // holds a session.
  // ignore: cancel_subscriptions
  static StreamSubscription<Object?>? _platformWatch;

  /// Subscribes once, and stays quiet about a platform that has nothing to say.
  static void _watchPlatform() {
    if (_platformWatch != null) {
      return;
    }

    _platformWatch = _statusChannel.receiveBroadcastStream().listen(
      _report,
      // No binding is not an event: a platform that cannot answer this has taken
      // nothing back, which is what the empty stream already says.
      onError: (Object _) {},
      cancelOnError: false,
    );
  }

  static void _report(Object? event) {
    final report = _parseReport(event);

    if (report != null) {
      _statuses.add(report);
    }
  }

  /// Reads one wire event, dropping a status name this version does not know.
  ///
  /// The plugin can be newer than the Dart side talking to it, and guessing that an
  /// unknown name means `stopped` would end a live job's protection on paper.
  static BackgroundSessionReport? _parseReport(Object? event) {
    if (event is! Map) {
      return null;
    }

    final status = switch (event['status']) {
      'degraded' => BackgroundExecutionStatus.degraded,
      'stopped' => BackgroundExecutionStatus.stopped,
      'protectionLost' => BackgroundExecutionStatus.protectionLost,
      _ => null,
    };
    final id = event['id'];

    if (status == null || id is! int) {
      return null;
    }

    return (id: id, status: status);
  }

  /// Feeds a report as if the platform had sent it. For tests only.
  ///
  /// The seam exists because the alternative is a mocked `EventChannel`, whose
  /// fan-out across several simultaneous subscriptions is not the behaviour a test
  /// should lean on. Wire form on purpose: parsing is half of what is being tested.
  @visibleForTesting
  static void debugPublishReport(Map<String, Object?> wire) => _report(wire);

  /// Wire form of a notification, shared by `acquire` and `update`.
  ///
  /// Public so a host implementing its own [BackgroundExecutionLease] against
  /// the same channel sends the same shape; the native side reads it in
  /// `BackgroundExecutionDelegate` and `JobForegroundService`.
  ///
  /// Progress says which of its two shapes it is (`indeterminate`) rather than
  /// leaving it to be inferred from missing numbers: "no total yet" and "no
  /// progress at all" are different things to draw.
  static Map<String, Object?> encodeNotification(BackgroundNotification notification) {
    final progress = notification.progress;

    return <String, Object?>{
      'title': notification.title,
      'text': notification.text,
      'kind': notification.kind.name,
      'icon': notification.icon,
      'progress': progress == null
          ? null
          : progress.isIndeterminate
          ? <String, Object?>{'indeterminate': true}
          : <String, Object?>{'current': progress.current, 'total': progress.total},
    };
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

  /// Replaces what the notification shows.
  ///
  /// This is how a long job keeps the shade honest: elapsed time, bytes written,
  /// a download's percentage. A platform that shows no notification does nothing
  /// here — the session's job is the protection, and a host should not have to
  /// ask which platform it is on to describe its own progress.
  ///
  /// After [release] this is a no-op: the session is gone, and a notification
  /// must not outlive it.
  Future<void> update(BackgroundNotification notification);

  /// Ends the session. Idempotent.
  Future<void> release();
}

/// One running session.
///
/// [update] and [release] are both safe to call twice, and both are no-ops once
/// the session ended: a job that stops after a failure and a job that stops on
/// request must not step on each other, and neither may release somebody else's
/// session.
final class BackgroundExecutionSession implements BackgroundExecutionLease {
  BackgroundExecutionSession._(this.id);

  @override
  final int id;

  bool _released = false;

  /// Whether the session is still held.
  @override
  bool get isActive => !_released;

  /// Replaces what the notification shows.
  @override
  Future<void> update(BackgroundNotification notification) async {
    if (_released) {
      return;
    }

    try {
      await BackgroundExecution._channel.invokeMethod<void>('update', <String, Object?>{
        'id': id,
        'notification': BackgroundExecution.encodeNotification(notification),
      });
    } on PlatformException {
      // A session the platform already tore down has no notification to update;
      // the job keeps running either way.
    } on MissingPluginException {
      // Same as the platforms that never had one.
    }
  }

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
