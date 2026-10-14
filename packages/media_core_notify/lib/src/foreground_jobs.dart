/// One notification for several running jobs, drawn from what the runtime holds.
///
/// The sessions live in `media_core`'s background runtime — every job acquired a
/// lease there, and the registry already knows their ids, words and priority — so
/// this class keeps no list of its own. It composes the line from
/// the runtime's `activeRequests` and reposts it when the registry says the
/// aggregate changed. Keeping the list in one place is the point: a second
/// bookkeeping of "what is running" is how a job ended up with two notifications
/// that disagreed.
///
/// On a platform whose job service already shows a persistent notification for
/// the sessions it holds — Android, where `media_core_native`'s foreground service
/// owns that line — this class composes and exposes the text and draws nothing.
/// Where no such service exists (iOS, macOS, Windows, Linux) it posts the line as
/// an ordinary notification: a recording on a Mac says so, and the process
/// protection was never this notification's job.
///
/// The line is reposted at most once per `ForegroundJobs.postGap`. A download updates its byte
/// count several times a second; a notification is not a live readout, and a
/// shelf that re-animates on every byte report is worse than one that says
/// "62%" a moment late.
library;

import 'dart:async';

import 'package:media_core/media_core.dart'
    show BackgroundCapability, BackgroundExecutionKind, BackgroundRequest, BackgroundRuntime, BackgroundRuntimes;
import 'package:media_core_native/media_core_native.dart' show BackgroundJobKind;

import 'package:media_core_notify/src/media_core_notify.dart';
import 'package:media_core_notify/src/notification_client.dart' show kRunningLineNotificationId;
import 'package:media_core_notify/src/notify_event.dart';

/// The running-jobs line.
abstract final class ForegroundJobs {
  /// How often the line may be reposted.
  static const Duration postGap = Duration(seconds: 1);

  static BackgroundRuntime? _runtime;
  static StreamSubscription<void>? _watch;
  static StreamSubscription<BackgroundRuntime?>? _waiting;
  static Timer? _gap;
  static bool _dirty = false;
  static bool _showingLine = false;

  /// The sessions contributing to the line, loudest first.
  static List<BackgroundRequest> get sessions => _runtime?.activeRequests ?? const <BackgroundRequest>[];

  /// Number of jobs the line is standing for.
  static int get runningCount => sessions.length;

  /// Whether the line has been posted and not yet cleared.
  static bool get isShowingLine => _showingLine;

  /// The title the line would show right now, or null with nothing running.
  static String? get lineTitle {
    final first = _first;

    return first?.title;
  }

  /// The body the line would show right now: the loudest job's own words, plus a
  /// count of what else is running.
  ///
  /// Exposed because composing this is the whole rule of the class, and a test —
  /// or a host drawing its own shelf — should read the rule, not a screenshot.
  static String? get lineBody {
    final first = _first;

    if (first == null) {
      return null;
    }

    return _compose(first, sessions.length - 1);
  }

  /// Whether this platform needs a Dart-drawn line at all.
  ///
  /// A backend that advertises [BackgroundCapability.persistentNotification] is a
  /// backend whose sessions already arrive on the user's shade through the service
  /// that holds them; drawing a second line here would be the duplicate the
  /// aggregate exists to avoid.
  static bool get drawsLine {
    final runtime = _runtime;

    if (runtime == null) {
      return false;
    }

    return !runtime.platformCapabilities.contains(BackgroundCapability.persistentNotification);
  }

  /// Draws the line for [runtime] — or for the installed runtime — including
  /// whatever is already running.
  ///
  /// With nothing installed yet it does not give up: it waits for the slot and
  /// attaches the first runtime that arrives. A host enables notifications in
  /// `main()` and the background backend appears at the first job, so a `watch()`
  /// that answered "no runtime, then" and stopped would leave the line silently
  /// never coming — the switch wired to nothing, which is the bug this class exists
  /// to remove rather than repeat. Idempotent.
  static void watch({BackgroundRuntime? runtime}) {
    final chosen = runtime ?? BackgroundRuntimes.current;

    if (chosen == null) {
      _waiting ??= BackgroundRuntimes.changes.listen((next) {
        if (next != null) {
          watch(runtime: next);
        }
      });

      return;
    }

    unawaited(_waiting?.cancel());
    _waiting = null;

    if (identical(_runtime, chosen)) {
      _repaint();

      return;
    }

    _detach();
    _runtime = chosen;
    _watch = chosen.changes.listen((_) => _repaint());
    _repaint();
  }

  /// Whether the line is armed: attached to a runtime, or waiting for one.
  static bool get isWatching => _runtime != null || _waiting != null;

  /// Takes the line down and stops watching, including while waiting for a runtime.
  ///
  /// For teardown and for a host that silences job notifications: the sessions
  /// themselves are untouched, so a running recording keeps its protection.
  static Future<void> hide() async {
    final wasShowing = _showingLine;

    unawaited(_waiting?.cancel());
    _waiting = null;
    _detach();

    if (wasShowing) {
      await _clear();
    }
  }

  /// Forgets the line's state without touching the platform. Test-only.
  static void resetForTest() {
    _gap?.cancel();
    _gap = null;
    _dirty = false;
    _showingLine = false;
    _watch = null;
    _waiting = null;
    _runtime = null;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static BackgroundRequest? get _first => sessions.isEmpty ? null : sessions.first;

  /// Stops watching, and lets the throttled repost die with it.
  static void _detach() {
    _gap?.cancel();
    _gap = null;
    _dirty = false;
    _showingLine = false;

    unawaited(_watch?.cancel());
    _watch = null;
  }

  /// Repaints the line: at once when it is not up yet, and at most once per
  /// [postGap] while it is.
  ///
  /// A repaint request that arrives inside an open window marks it dirty and the
  /// deadline re-posts the newest content — one timer per window, whatever number
  /// of byte reports came in between.
  static void _repaint() {
    if (!drawsLine) {
      // The platform's own service is the one that says what is running. There is
      // nothing to repost, and a dirty flag would only make the next window fire
      // an empty flush.
      return;
    }

    if (sessions.isEmpty) {
      // Nothing to show: the window closes with the line rather than staying open
      // over an empty shade, because the job that starts next should be visible
      // the moment it does.
      _gap?.cancel();
      _gap = null;
      _dirty = false;

      if (_showingLine) {
        _showingLine = false;
        unawaited(_clear());
      }

      return;
    }

    if (_gap != null) {
      _dirty = true;

      return;
    }

    _dirty = false;
    // Claimed here rather than inside the flush: a repost in flight is a line that
    // is up, and the next release has to compare against that.
    _showingLine = true;

    unawaited(_flush());

    _gap = Timer(postGap, _onDeadline);
  }

  static void _onDeadline() {
    _gap = null;

    if (_dirty) {
      _dirty = false;

      _repaint();
    }
  }

  static Future<void> _flush() async {
    final client = MediaCoreNotify.client;
    final first = _first;

    if (client == null || first == null) {
      return;
    }

    try {
      await client.showRunningLine(_eventFor(first, sessions.length - 1));
    } on Exception {
      // A refused repost must not strand the group's timer state.
    }
  }

  static Future<void> _clear() async {
    try {
      await MediaCoreNotify.client?.clearRunningLine();
    } on Exception {
      // Nothing to do about a notification that could not be taken away.
    }
  }

  static NotifyEvent _eventFor(BackgroundRequest request, int others) {
    return NotifyEvent(
      title: request.title,
      body: _compose(request, others),
      tone: NotifyTone.progress,
      channel: MediaCoreNotify.setup.jobsChannel,
      kind: _kindOf(request.kind),
      id: kRunningLineNotificationId,
    );
  }

  static BackgroundJobKind _kindOf(BackgroundExecutionKind kind) => switch (kind) {
    BackgroundExecutionKind.recording => BackgroundJobKind.record,
    BackgroundExecutionKind.download => BackgroundJobKind.download,
    BackgroundExecutionKind.generic => BackgroundJobKind.task,
  };

  /// The loudest job's own words, plus a count of what else is running.
  static String? _compose(BackgroundRequest newest, int others) {
    final text = newest.description;

    if (others <= 0) {
      return (text == null || text.isEmpty) ? null : text;
    }

    final suffix = '还有 $others 个任务';

    if (text == null || text.isEmpty) {
      return suffix;
    }

    return '$text  ($suffix)';
  }
}
