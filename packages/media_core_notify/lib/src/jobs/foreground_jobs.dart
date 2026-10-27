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
        BackgroundJobProgress,
        BackgroundRequest,
        BackgroundRuntime,
        BackgroundRuntimeOwners,
        BackgroundRuntimes,
        BackgroundServiceOwner,
        LogCategory,
        LogModule,
        MediaCoreLog;
import 'package:media_core_native/media_core_native.dart' show BackgroundJobKind;
import 'package:media_core_notify/src/client/notification_client.dart' show runningLineIdFor;
import 'package:media_core_notify/src/client/notify_event.dart';
import 'package:media_core_notify/src/media_core_notify.dart';

final LogModule _log = MediaCoreLog.of(LogCategory.general);

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
  /// to remove rather than repeat. The slot is followed after that first attach too:
  /// replacing the installed runtime is the same mistake seen from the other side,
  /// leaving a projector watching a runtime no job uses any more. Idempotent.
  static void watch({BackgroundRuntime? runtime}) {
    final chosen = runtime ?? BackgroundRuntimes.current;

    _waiting ??= BackgroundRuntimes.changes.listen((next) {
      if (next == null) {
        // The runtime was deposed entirely; watching its corpse would keep
        // every line armed for sessions that no longer report.
        unawaited(_watch?.cancel());
        _watch = null;
        _runtime = null;
        _detach().forEach(unawaited);

        return;
      }

      if (!identical(next, _runtime)) {
        watch(runtime: next);
      }
    });

    if (chosen == null) {
      return;
    }

    if (identical(_runtime, chosen)) {
      _repaint();

      return;
    }

    _detach().forEach(unawaited);

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
    unawaited(_waiting?.cancel());
    _waiting = null;
    unawaited(_watch?.cancel());
    _watch = null;
    // Hidden means not armed: a later idempotent watch() must re-attach and
    // repaint, not short-circuit on the runtime the host silenced.
    _runtime = null;

    await Future.wait(_detach());
  }

  /// Says the line whose notification id is [id] is off the shade, though this
  /// class did not take it down.
  ///
  /// [MediaCoreNotify.dismiss] calls it, and a host that clears a line through its
  /// own notification pipeline should too: without it the projector still believes
  /// the line is up, `isShowingLine` answers about a notification that is not there,
  /// and the skip-when-unchanged rule then waits for a *text* change to notice.
  /// Nothing is reposted from here — a line that was removed is left removed until
  /// the feature's own state moves, which is what the user's gesture asked for.
  static void lineWasRemoved(int id) {
    for (final line in _lines.values) {
      if (line.id != id) {
        continue;
      }

      // The window closes with the line: opening one is never throttled, so when the
      // feature's own text next moves the line goes up at once rather than at the end
      // of a window that was measuring a notification nobody is looking at.
      _closeGap(line);
      line
        ..showing = false
        ..dismissed = true
        ..gap = null
        ..dirty = false;
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

  /// Stops watching, takes down whatever was on the shade, and returns the clears
  /// so a caller that wants to await them can.
  ///
  /// The take-down is the point: these lines belong to the runtime being left, and
  /// the next runtime has no idea they exist. Forget them without clearing them and
  /// an ongoing-looking notification stays forever describing work nobody holds —
  /// which is the same lie as a line that outlives its last job by a second.
  static List<Future<void>> _detach() {
    final pending = <Future<void>>[];

    for (final line in _lines.values) {
      line.gap?.cancel();

      if (line.showing) {
        pending.add(_clear(line.id));
      }
    }

    _lines.clear();

    unawaited(_watch?.cancel());
    _watch = null;

    return pending;
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

  /// Whole-percent aggregate progress of [owner]'s sessions, or null when
  /// none carries a fraction.
  static int? _fractionPercentFor(BackgroundServiceOwner owner) {
    final aggregate = _aggregateProgress(sessionsFor(owner));

    return aggregate == null ? null : ((aggregate.fraction ?? 0) * 100).round();
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

    if ((line.showing || line.dismissed) && line.title == title && line.body == body) {
      final drawn = line.fractionPercent;
      final current = _fractionPercentFor(owner);

      if (line.dismissed || drawn == current) {
        // Same words and the same (or absent) bar: another feature's change
        // woke this projector, and this line says exactly what it already
        // says - or the exact thing the viewer swiped away. Reposting it
        // would re-alert a notification nobody asked to move.
        return;
      }

      // Text identical but the bar moved: a host whose description is static
      // while its fraction advances would otherwise freeze the drawn progress
      // forever. Whole percents only - that is what the platform draws.
      line.fractionPercent = current;
      unawaited(_flush(owner, line, title, body));
      line.gap?.cancel();
      line.gap = Timer(postGap, () => _onDeadline(owner, line));

      return;
    }

    // Different text: the dismissal belongs to the old words, not the line.
    line.dismissed = false;

    if (line.gap != null) {
      line.dirty = true;

      return;
    }

    line.dirty = false;
    // Not claimed before the platform answers. A repost the plugin refused leaves
    // nothing on the shade, and a line that believed it was up would compare its
    // own text against what nobody ever saw and never try again.
    unawaited(_flush(owner, line, title, body));

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

  static Future<void> _flush(BackgroundServiceOwner owner, _Line line, String? title, String? body) async {
    final client = MediaCoreNotify.client;
    final first = _firstFor(owner);

    if (client == null || first == null || title == null) {
      return;
    }

    final sessions = sessionsFor(owner);
    final others = sessions.length - 1;
    final aggregate = _aggregateProgress(sessions);

    final event = NotifyEvent(
      title: first.title,
      body: _compose(first, others),
      tone: NotifyTone.progress,
      channel: MediaCoreNotify.setup.channelFor(owner),
      kind: _kindOf(first.kind),
      id: line.id,
      progress: aggregate?.fraction,
      indeterminate: aggregate == null && sessions.any((request) => request.progress != null),
    );

    try {
      await client.showRunningLine(event);
    }
    // Broad on purpose: this runs inside the runtime's change event, and an error
    // escaping here would cancel the subscription and take every feature's line
    // down with it. One failed repost is a retry; a dead projector is silent
    // notifications for the rest of the process.
    on Object catch (error) {
      // Nothing is on the shade, so the line is not shown — and it stays dirty, so
      // the end of this repost window tries again rather than the projector
      // settling for a notification that was never drawn.
      _log.warning('notification show failed', error: error);
      line
        ..showing = false
        ..fractionPercent = null
        ..dirty = true;

      return;
    }

    line
      ..showing = true
      ..title = title
      ..body = body
      ..fractionPercent = aggregate == null ? null : ((aggregate.fraction ?? 0) * 100).round();
  }

  static Future<void> _clear(int id) async {
    try {
      await MediaCoreNotify.client?.clearRunningLine(id: id);
    }
    // Same reason as the repost: a line that could not be taken down must not end
    // the projector, and the retry-on-next-change behaviour of a *shown* line does
    // not apply here — an id still on the shade is cleared again by the next
    // repaint that finds its feature empty.
    on Object catch (error) {
      // Nothing to do about a notification that could not be taken away.
      _log.warning('notification clear failed', error: error);
    }
  }

  static BackgroundJobKind _kindOf(BackgroundExecutionKind kind) => switch (kind) {
    BackgroundExecutionKind.recording => BackgroundJobKind.record,
    BackgroundExecutionKind.download => BackgroundJobKind.download,
    BackgroundExecutionKind.generic => BackgroundJobKind.task,
  };

  /// One aggregate over the feature's sessions: the sum of every determinate
  /// job's units, the way a queue's progress bar means "this batch".
  ///
  /// Null when no session carries a determinate progress. An indeterminate bar
  /// (some session tracks progress but none can be summed) is answered through
  /// the second record field, not here.
  static BackgroundJobProgress? _aggregateProgress(List<BackgroundRequest> sessions) {
    var current = 0;
    var total = 0;
    var determinate = false;

    for (final request in sessions) {
      final progress = request.progress;
      if (progress == null || progress.isIndeterminate) {
        continue;
      }
      determinate = true;
      current += progress.current ?? 0;
      total += progress.total ?? 0;
    }

    if (!determinate || total <= 0) {
      return null;
    }

    return BackgroundJobProgress.determinate(current: current, total: total);
  }

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

  /// The viewer swiped this line away; it must not come back until its own
  /// text actually moves, which is what the dismissal asked for.
  bool dismissed = false;

  /// Last-drawn aggregate progress in whole percents, for the bar-only move.
  int? fractionPercent;
  Timer? gap;
  String? title;
  String? body;
}
