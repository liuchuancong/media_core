/// One notification per feature, drawn from what the runtime holds.
///
/// The sessions live in `media_core`'s background runtime — every job acquired a
/// lease there, and the registry already knows their ids, words and priority — so
/// this class keeps no list of jobs of its own. It reads the runtime's sessions for
/// one feature, composes that feature's line and reposts it when the registry says
/// the aggregate changed. Keeping the list in the runtime is the point: a second
/// bookkeeping of "what is running" is how a job ended up with two notifications
/// that disagreed.
///
/// **One line per feature, never one line for all of them.** Recording, download and
/// unnamed work each get their own notification id and their own channel, so the
/// last transfer finishing clears the download line and leaves a recording's text
/// exactly where it was, and a user can silence one feature without losing the
/// other. The count a line carries ("还有 N 个任务") counts that feature's other
/// sessions only.
///
/// On a platform whose job service already shows a persistent notification for
/// the sessions it holds — Android, where `media_core_native`'s per-feature
/// foreground services own those lines — this class composes and exposes the text
/// and draws nothing. Where no such service exists (iOS, macOS, Windows, Linux) it
/// posts the lines as ordinary notifications: a recording on a Mac says so, and the
/// process protection was never this notification's job.
///
/// Each line is reposted at most once per `ForegroundJobs.postGap`, and not at all
/// when its own text did not change. A download updates its byte count several times
/// a second; a notification is not a live readout, and a shelf that re-animates on
/// every byte report is worse than one that says "62%" a moment late. Opening and
/// closing a line is never throttled: a line that survives the last job of its
/// feature by a second says work is running when it stopped.
library;

import 'dart:async';

import 'package:media_core/media_core.dart'
    show
        BackgroundCapability,
        BackgroundExecutionKind,
        BackgroundRequest,
        BackgroundRuntime,
        BackgroundRuntimeOwners,
        BackgroundRuntimes,
        BackgroundServiceOwner;
import 'package:media_core_native/media_core_native.dart' show BackgroundJobKind;
import 'package:media_core_notify/src/client/notification_client.dart' show runningLineIdFor;
import 'package:media_core_notify/src/client/notify_event.dart';
import 'package:media_core_notify/src/media_core_notify.dart';

/// The running lines, one per feature.
abstract final class ForegroundJobs {
  /// How often a line may be reposted.
  static const Duration postGap = Duration(seconds: 1);

  static BackgroundRuntime? _runtime;
  static StreamSubscription<void>? _watch;
  static StreamSubscription<BackgroundRuntime?>? _waiting;

  /// The line state of one feature, alive only while that feature has one.
  static final Map<BackgroundServiceOwner, _Line> _lines = <BackgroundServiceOwner, _Line>{};

  /// Every job session the runtime holds, loudest first.
  static List<BackgroundRequest> get sessions => _runtime?.activeRequests ?? const <BackgroundRequest>[];

  /// The sessions of [owner], loudest first — the aggregate that one line shows.
  static List<BackgroundRequest> sessionsFor(BackgroundServiceOwner owner) =>
      _runtime?.requestsFor(owner) ?? const <BackgroundRequest>[];

  /// Number of jobs every line is standing for together.
  static int get runningCount => sessions.length;

  /// Whether any line is posted and not yet cleared.
  static bool get isShowingLine => _lines.values.any((line) => line.showing);

  /// Whether the line for [owner] is posted.
  static bool isShowingLineFor(BackgroundServiceOwner owner) => _lines[owner]?.showing ?? false;

  /// The title [owner]'s line would show right now, or null with nothing running.
  static String? titleFor(BackgroundServiceOwner owner) => _firstFor(owner)?.title;

  /// The body [owner]'s line would show right now: its loudest job's own words,
  /// plus a count of what else *that feature* is running.
  ///
  /// Exposed because composing this is the whole rule of the class, and a test — or
  /// a host drawing its own shelf — should read the rule, not a screenshot.
  static String? bodyFor(BackgroundServiceOwner owner) {
    final first = _firstFor(owner);

    if (first == null) {
      return null;
    }

    return _compose(first, sessionsFor(owner).length - 1);
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

  /// Draws the lines for [runtime] — or for the installed runtime — including
  /// whatever is already running.
  ///
  /// With nothing installed yet it does not give up: it waits for the slot and
  /// attaches the first runtime that arrives. A host enables notifications in
  /// `main()` and the background backend appears at the first job, so a `watch()`
  /// that answered "no runtime, then" and stopped would leave the lines silently
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

  /// Whether the lines are armed: attached to a runtime, or waiting for one.
  static bool get isWatching => _runtime != null || _waiting != null;

  /// Takes every line down and stops watching, including while waiting for a
  /// runtime.
  ///
  /// For teardown and for a host that silences job notifications: the sessions
  /// themselves are untouched, so a running recording keeps its protection.
  static Future<void> hide() async {
    final showing = _lines.values.where((line) => line.showing).map((line) => line.id).toList();

    unawaited(_waiting?.cancel());
    _waiting = null;
    _detach();

    for (final id in showing) {
      await _clear(id);
    }
  }

  /// Forgets the lines' state without touching the platform. Test-only.
  static void resetForTest() {
    _lines.values.forEach(_closeGap);
    _lines.clear();
    _watch = null;
    _waiting = null;
    _runtime = null;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static BackgroundRequest? _firstFor(BackgroundServiceOwner owner) {
    final requests = sessionsFor(owner);

    return requests.isEmpty ? null : requests.first;
  }

  /// Stops watching, and lets every throttled repost die with it.
  static void _detach() {
    _lines.values.forEach(_closeGap);
    _lines.clear();

    unawaited(_watch?.cancel());
    _watch = null;
  }

  static void _closeGap(_Line line) => line.gap?.cancel();

  static _Line _lineFor(BackgroundServiceOwner owner) =>
      _lines.putIfAbsent(owner, () => _Line(runningLineIdFor(owner)));

  /// Repaints every feature's line: each one at once when it is not up yet, and at
  /// most once per [postGap] while it is.
  ///
  /// A line with nothing under it goes down immediately. A repaint request inside an
  /// open window marks that line dirty and its deadline re-posts the newest content —
  /// one timer per line, whatever number of byte reports came in between, and a
  /// change to one feature never spends another feature's window.
  static void _repaint() {
    if (!drawsLine) {
      // The platform's own services are the ones that say what is running. There is
      // nothing to repost, and a dirty flag would only make the next window fire an
      // empty flush.
      return;
    }

    BackgroundServiceOwner.jobOwners.forEach(_repaintOne);
  }

  static void _repaintOne(BackgroundServiceOwner owner) {
    final line = _lineFor(owner);
    final title = titleFor(owner);
    final body = bodyFor(owner);

    if (title == null) {
      // Nothing to show: the window closes with the line rather than staying open
      // over an empty shade, because the job that starts next should be visible the
      // moment it does.
      line.gap?.cancel();
      _lines.remove(owner);

      if (line.showing) {
        line.showing = false;
        unawaited(_clear(line.id));
      }

      return;
    }

    if (line.showing && line.title == title && line.body == body) {
      // Another feature's change woke this projector, and this line says the same
      // thing it already says. Reposting it would re-alert a notification nobody
      // asked to move.
      return;
    }

    if (line.gap != null) {
      line.dirty = true;

      return;
    }

    line
      ..dirty = false
      ..title = title
      ..body = body
      // Claimed here rather than inside the flush: a repost in flight is a line that
      // is up, and the next release has to compare against that.
      ..showing = true;

    unawaited(_flush(owner, line));

    line.gap = Timer(postGap, () => _onDeadline(owner, line));
  }

  static void _onDeadline(BackgroundServiceOwner owner, _Line line) {
    line.gap = null;

    if (!line.dirty) {
      return;
    }

    line.dirty = false;

    if (_lines.containsKey(owner)) {
      _repaintOne(owner);
    }
  }

  static Future<void> _flush(BackgroundServiceOwner owner, _Line line) async {
    final client = MediaCoreNotify.client;
    final first = _firstFor(owner);

    if (client == null || first == null) {
      return;
    }

    final others = sessionsFor(owner).length - 1;

    final event = NotifyEvent(
      title: first.title,
      body: _compose(first, others),
      tone: NotifyTone.progress,
      channel: MediaCoreNotify.setup.channelFor(owner),
      kind: _kindOf(first.kind),
      id: line.id,
    );

    try {
      await client.showRunningLine(event);
    } on Exception {
      // A refused repost must not strand the line's timer state.
    }
  }

  static Future<void> _clear(int id) async {
    try {
      await MediaCoreNotify.client?.clearRunningLine(id: id);
    } on Exception {
      // Nothing to do about a notification that could not be taken away.
    }
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

/// One feature's line: its notification id and the state of its repost window.
final class _Line {
  _Line(this.id);

  /// The notification this line owns, for as long as the feature has a session.
  final int id;

  bool showing = false;
  bool dirty = false;
  Timer? gap;
  String? title;
  String? body;
}
