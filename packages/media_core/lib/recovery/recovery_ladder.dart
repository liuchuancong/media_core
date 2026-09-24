import 'dart:async';
import 'recovery_step.dart';
import 'package:clock/clock.dart';
import '../diagnostics/log_category.dart';
import '../diagnostics/media_core_log.dart';
import 'recovery_budget.dart';
import 'recovery_state.dart';
import 'recovery_action.dart';
import 'recovery_policy.dart';
import 'recovery_target.dart';
import 'recovery_session.dart';
import 'recovery_context.dart';
import 'recovery_failure.dart';
import 'recovery_snapshot.dart';
import 'recovery_ladder_event.dart';
import 'recovery_candidate_provider.dart';

/// Lifecycle of the ladder.
enum RecoveryLadderStatus {
  /// No run in progress and none finished.
  idle,

  /// A run is escalating.
  running,

  /// A run ended because a step succeeded.
  completed,

  /// A run ended because no step was left.
  exhausted,

  /// Runs are refused until [RecoveryLadder.resume] is called.
  suspended,

  /// The ladder was released.
  disposed,
}

/// The recovery ladder: one sequential escalation per failure.
///
/// This is the only place in the framework that decides what to do
/// about a playback failure. Earlier the same decision was made in
/// three places at once — the handle retried with backoff, the kernel
/// ran a backend-fallback loop, and the live controller ran its own
/// ladder — and each of them invalidated the others' operations, so a
/// single failure produced a burst of open/close cycles.
///
/// The ladder replaces all three with one driver:
///
/// ```text
/// report(failure)
///   │  entry decision      → RecoveryLadderPolicy (delegates to ErrorPolicy)
///   │  decision context    → RecoverySession, built by the target
///   ▼
/// escalate: sameBackendReopen → nextLine → nextBackend → backoff → rescan
///   │  execution           → RecoveryTarget
///   │  observation         → RecoveryLadderEvent stream
///   ▼
/// completed | exhausted | cancelled
/// ```
///
/// ## Escalation shape
///
/// The sweep is **engine-major, line-minor**: every engine gets its own
/// attempt on the current line, then its own pass over every remaining
/// line, and only when an engine has nothing left does the ladder attach
/// the next one.
///
/// ```text
/// engine A  reopen(current line) · line 2 · line 3 · line 4
/// engine B  reopen(current line) · line 2 · line 3 · line 4
/// engine C  reopen(current line) · line 2 · line 3 · line 4
///           → exhausted: nothing left to try
/// ```
///
/// Both halves of that shape are load-bearing:
///
/// - **per engine line sweep** — a line that failed on engine A says
///   nothing about engine B. They differ in demuxer, network stack and
///   decoder, and sharing one "tried" set across engines would spend the
///   entire line list on the first engine and leave the others with
///   nothing to try;
/// - **per engine budgets** — reopens, lines and waits are counted per
///   engine, so an engine that burned its allowance cannot consume the
///   next engine's.
///
/// The run ends in [RecoveryLadderExhausted] only after every engine has
/// swept every line, which is what lets a caller report "cannot play" to
/// the user with confidence that the framework really did try.
///
/// Design rules that keep it from becoming a fourth parallel path:
///
/// - **One run at a time.** [report] refuses while a step is in flight;
///   a repeat of the same failure only shortens a backoff wait.
/// - **Sequential, not concurrent.** Steps are awaited in order. The
///   ladder is a loop, not a set of callbacks racing each other.
/// - **Everything physical goes through the target.** The ladder never
///   touches an adapter, a registry or a session controller.
/// - **Bounded.** Four dimensions plus a total ceiling, so it always
///   terminates.
/// - **Abortable.** [reset], [suspend] and [dispose] bump an internal
///   generation, so a step that is still in flight cannot commit a
///   decision into a run that no longer exists.
final class RecoveryLadder {
  /// Creates a ladder.
  RecoveryLadder({
    required this.target,
    required this.candidates,
    this.policy = const DefaultRecoveryLadderPolicy(),
    this.budget = RecoveryBudget.defaults,
  }) {
    _targetEvents = target.executionEvents.listen(_onTargetEvent, onError: (Object _) {});
  }

  /// Layer that executes the physical steps.
  final RecoveryTarget target;

  /// Source of alternative sources and backends.
  final RecoveryCandidateProvider candidates;

  /// Entry + escalation policy.
  final RecoveryLadderPolicy policy;

  /// Attempt budget.
  final RecoveryBudget budget;

  final StreamController<RecoveryLadderEvent> _events = StreamController<RecoveryLadderEvent>.broadcast();

  StreamSubscription<RecoveryTargetEvent>? _targetEvents;
  Timer? _timer;
  Completer<bool>? _waiting;
  Future<void>? _run;

  /// Steps spent per engine, per kind.
  ///
  /// Keyed by backend so each engine gets its own allowance: an engine
  /// that burned its reopens must not consume the next engine's budget.
  /// An empty key (`''`) holds the steps spent before any backend is
  /// known — the first engine is the one already attached.
  final Map<String, Map<RecoveryStepKind, int>> _stepCounts = <String, Map<RecoveryStepKind, int>>{};

  RecoveryLadderStatus _status = RecoveryLadderStatus.idle;
  RecoveryFailure? _failure;
  RecoverySession? _session;
  int _attempts = 0;

  /// Bumped by every start and every abort.
  ///
  /// A driver captures it before it awaits anything and re-checks it
  /// afterwards, so an interrupted run cannot resume into a newer one.
  int _generation = 0;

  bool _disposed = false;

  /// Decision events of this ladder.
  Stream<RecoveryLadderEvent> get events => _events.stream;

  /// Current lifecycle status.
  RecoveryLadderStatus get status => _status;

  /// Whether a run is currently escalating.
  bool get isRunning => _status == RecoveryLadderStatus.running;

  /// Whether the ladder accepts a new failure report.
  bool get acceptsReports => !_disposed && _status != RecoveryLadderStatus.suspended;

  /// Failure of the current (or last) run.
  RecoveryFailure? get failure => _failure;

  /// Decision context of the current (or last) run.
  RecoverySession? get session => _session;

  /// Setups that recovered and then broke again shortly after.
  ///
  /// Recovery that "succeeds" and fails again inside [_repeatWindow] is
  /// not recovery: the setup itself is unfit, and repeating the same rung
  /// only postpones the escalation. A streak makes the next run start
  /// higher up the ladder — reopen, then next line, then next backend —
  /// which is what turns "freeze · reopen · freeze · reopen …" into
  /// "freeze · next line · freeze · next backend · give up".
  ///
  /// Keyed by engine and source, so changing either one starts a fresh
  /// streak: the new combination has not been tried yet.
  final Map<String, ({int count, DateTime at})> _streaks = <String, ({int count, DateTime at})>{};

  /// How often one ENGINE may stall (on any line) before the ladder
  /// stops offering it lines and moves to the next engine.
  ///
  /// A per-setup streak alone cannot condemn an engine: soft-decode
  /// starvation freezes *every* line, and each new line would start a
  /// fresh streak, costing a full stall cycle each. The engine counter is
  /// what turns "line 1 froze, line 2 froze" into "this engine cannot
  /// play this stream" after two cycles instead of five.
  static const int _engineStallLimit = 2;

  /// How long a recovery is considered to have "held" before it counts as
  /// a repeat rather than a new fault.
  static const Duration _repeatWindow = Duration(minutes: 2);

  /// Stalls per engine, for the engine-level condemnation above.
  final Map<String, ({int count, DateTime at})> _engineStalls = <String, ({int count, DateTime at})>{};

  /// Stalls recorded per engine, for diagnostics.
  Map<String, int> get engineStallCounts {
    return Map<String, int>.unmodifiable(_engineStalls.map((key, value) => MapEntry(key, value.count)));
  }

  /// Setups currently considered repeat offenders.
  Map<String, int> get repeatStreaks {
    return Map<String, int>.unmodifiable(_streaks.map((key, value) => MapEntry(key, value.count)));
  }

  /// Number of steps executed in the current (or last) run.
  int get attempt => _attempts;

  /// Steps executed per engine and kind in the current (or last) run.
  Map<String, Map<RecoveryStepKind, int>> get stepCounts {
    return Map<String, Map<RecoveryStepKind, int>>.unmodifiable(_stepCounts);
  }

  /// Completes when the current run settles.
  ///
  /// Awaiting this is how a caller (or a test) observes the whole
  /// escalation without subscribing to events.
  Future<void> get settled => _run ?? Future<void>.value();

  /// Diagnostic snapshot of the ladder in the recovery module's shape.
  RecoverySnapshot get snapshot {
    final current = _failure;

    return RecoverySnapshot(
      state: _recoveryState(),
      context: current == null
          ? null
          : RecoveryContext(
              reason: current.effectiveReason,
              sourceId: current.sourceId,
              generationId: current.generationId,
              message: current.message,
              metadata: <String, Object?>{
                'reporter': current.source.name,
                'engines': _stepCounts.length,
                'attempts': _attempts,
              },
            ),
    );
  }

  /// Reports a failure and starts escalating.
  ///
  /// Returns `true` when the ladder accepted the report and started a
  /// run. Returns `false` when it did not, in which case the failure is
  /// not being recovered:
  ///
  /// - a run is already escalating (a second driver must not start —
  ///   that is the thrash this ladder exists to prevent);
  /// - the ladder is suspended, disposed, or has no usable budget.
  ///
  /// A report that arrives while the ladder is waiting out a backoff
  /// shortens that wait: a fresh failure is proof the outage is still
  /// there, so there is nothing to gain by sleeping.
  bool report(RecoveryFailure failure) {
    if (_disposed) {
      return false;
    }

    if (_status == RecoveryLadderStatus.suspended) {
      MediaCoreLog.warning(
        LogCategory.recovery,
        'report ignored: ladder is suspended (a user action paused playback)',
        fields: <String, Object?>{'stableKey': failure.stableKey, 'message': failure.message},
      );

      return false;
    }

    if (_status == RecoveryLadderStatus.running) {
      // A second driver for a failure already being recovered is exactly
      // the duplicate work this ladder exists to prevent, so the report is
      // refused — but a wait in progress is cut short, because the new
      // evidence says the outage is still there.
      final waiting = _waiting != null;

      _releaseWait(continueRun: true);

      MediaCoreLog.debug(
        LogCategory.recovery,
        'report ignored: ladder already running'
            '${waiting ? ' (backoff cut short)' : ''}',
        fields: <String, Object?>{'stableKey': failure.stableKey, 'attempt': _attempts},
      );

      return false;
    }

    if (!budget.allowsRecovery && !budget.allowsBackoff) {
      _failure = failure;
      _status = RecoveryLadderStatus.exhausted;
      _emit(RecoveryLadderExhausted(attempt: 0, message: 'Recovery budget allows no steps.', failure: failure));

      return false;
    }

    final generation = ++_generation;

    final escalate = _escalationFor(failure);

    _status = RecoveryLadderStatus.running;
    _failure = failure;
    _attempts = 0;
    _stepCounts.clear();
    _run = _drive(failure, generation, escalate);

    return true;
  }

  /// How many rungs this fault has already proven useless on.
  ///
  /// Two memories feed it: the per-setup streak (this engine froze on this
  /// line before) and the per-engine count (this engine froze, wherever).
  /// The engine count is the stronger verdict — reaching
  /// [_engineStallLimit] skips the engine's remaining rungs entirely and
  /// starts the plan at the next backend.
  int _escalationFor(RecoveryFailure failure) {
    final engine = failure.backendId ?? '';
    final engineStall = _engineStalls[engine];

    if (engineStall != null && clock.now().difference(engineStall.at) <= _repeatWindow) {
      if (engineStall.count >= _engineStallLimit) {
        MediaCoreLog.warning(
          LogCategory.recovery,
          'engine "$engine" stalled ${engineStall.count} time(s) recently — '
              'skipping its remaining rungs, escalating to the next backend',
          fields: <String, Object?>{'engine': engine, 'windowSeconds': _repeatWindow.inSeconds},
        );

        // retryPlan is [reopen, nextLine, nextBackend, backoff]: skipping
        // two rungs starts at the next backend. fallbackPlan (a source
        // failure) already skips the reopen, so one more rung lands on
        // the same rung.
        return 2;
      }
    } else if (engineStall != null) {
      _engineStalls.remove(engine);
    }

    final streak = _streaks[_setupKeyOf(failure)];

    if (streak == null) {
      return 0;
    }

    if (clock.now().difference(streak.at) > _repeatWindow) {
      _streaks.remove(_setupKeyOf(failure));

      return 0;
    }

    return streak.count;
  }

  /// Identity of the engine + source pair a failure belongs to.
  String _setupKeyOf(RecoveryFailure failure) {
    return '${failure.backendId ?? '-'}|${failure.sourceId?.value ?? failure.uri ?? '-'}';
  }

  /// Identity of the engine + source pair of [session].
  String _setupKey(RecoverySession session) {
    return '${session.backendId ?? '-'}|${session.source?.id.value ?? '-'}';
  }

  /// Drops the rungs a repeat failure has already climbed.
  ///
  /// The escalation order of [plan] is the order rungs are meant to be
  /// tried in, so skipping its first [escalate] physical rungs is exactly
  /// "start where the last attempt left off". Never returns an empty plan:
  /// when everything has been skipped, the deepest rung is retried once
  /// more so the run still terminates on the candidate lists running out
  /// rather than on a planner quirk.
  List<RecoveryStepKind> _effectivePlan(List<RecoveryStepKind> plan, int escalate) {
    if (escalate <= 0 || plan.isEmpty) {
      return plan;
    }

    final rungs = plan.where((kind) => kind != RecoveryStepKind.backoff).toList();

    if (rungs.isEmpty) {
      return plan;
    }

    final remaining = rungs.skip(escalate).toList();

    if (remaining.isEmpty) {
      return <RecoveryStepKind>[
        rungs.last,
        if (plan.contains(RecoveryStepKind.backoff)) RecoveryStepKind.backoff,
      ];
    }

    return <RecoveryStepKind>[
      ...remaining,
      if (plan.contains(RecoveryStepKind.backoff)) RecoveryStepKind.backoff,
    ];
  }

  /// Stops the current run and returns to [RecoveryLadderStatus.idle].
  ///
  /// Called when the lifecycle moves on: a new source open, a close, a
  /// recycle. Recovery for a source that is no longer playing is stale
  /// by definition.
  void reset() {
    if (_disposed) {
      return;
    }

    _abort('Recovery ladder was reset.');
    _status = RecoveryLadderStatus.idle;
  }

  /// Stops the current run and refuses new ones until [resume].
  ///
  /// Called when the user takes over (pause, stop, deactivate): a user
  /// intent is a recovery boundary, not a recovery opportunity.
  void suspend() {
    if (_disposed) {
      return;
    }

    _abort('Recovery ladder was suspended.');
    _status = RecoveryLadderStatus.suspended;
  }

  /// Accepts reports again after [suspend].
  void resume() {
    if (_disposed) {
      return;
    }

    if (_status == RecoveryLadderStatus.suspended) {
      _status = RecoveryLadderStatus.idle;
    }
  }

  /// Releases the ladder.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _abort('Recovery ladder was disposed.');
    _status = RecoveryLadderStatus.disposed;

    await _targetEvents?.cancel();
    _targetEvents = null;

    await _events.close();
  }

  // ---------------------------------------------------------------------------
  // Driving
  // ---------------------------------------------------------------------------

  Future<void> _drive(RecoveryFailure failure, int generation, [int escalateFrom = 0]) async {
    try {
      if (!target.isRecoveryAvailable) {
        _finishExhausted(generation, failure, 'Recovery target is not available.');

        return;
      }

      final session = target.buildRecoverySession(failure, candidates.candidatesFor(failure));

      _session = session;

      final proposed = policy.plan(failure, session);
      var plan = _effectivePlan(proposed, escalateFrom);

      _emit(RecoveryLadderStarted(failure: failure, plan: plan, budget: budget, superseded: escalateFrom > 0));

      MediaCoreLog.info(
        LogCategory.recovery,
        'ladder started: ${plan.isEmpty ? '<no step allowed>' : plan.map((kind) => kind.name).join(' -> ')}'
            '${escalateFrom > 0 ? ' (escalated past $escalateFrom rung(s): this setup already failed after recovering)' : ''}',
        fields: <String, Object?>{
          'reportedBy': failure.source.name,
          'code': failure.code.value,
          'reason': failure.effectiveReason.toString(),
          'message': failure.message,
          'stableKey': failure.stableKey,
          'label': session.label,
          'wasPlaying': session.wasPlaying,
          'positionMs': session.position.inMilliseconds,
          'lines': session.sourceCandidates.length,
          'backends': session.backendCandidates.map((registration) => registration.id).toList(),
          'budget': budget.toMap(),
        },
      );

      if (plan.isEmpty) {
        _finishExhausted(generation, failure, 'Policy produced no recovery step.');

        return;
      }

      // The line sweep is per engine. A source that failed on one engine
      // says nothing about the next one: engines differ in demuxer,
      // network stack and decoder, and one of them may well play the
      // stream the previous one refused. This is what makes the
      // escalation engine-major:
      //
      //     engine A: line 1, line 2, line 3, line 4
      //     engine B: line 1, line 2, line 3, line 4
      //     engine C: ...
      //
      // A single shared set would spend every line on the first engine
      // and leave the others with nothing to try.
      final sweptSources = <String, Set<String>>{};
      final triedBackends = <String>{
        if (session.backendId != null) session.backendId!,
      };

      var backoffAttempt = 0;
      var previousFailure = failure;
      final ceiling = _totalCeiling(session);

      _ceiling = ceiling;

      while (_isCurrent(generation)) {
        if (_attempts >= ceiling) {
          _finishExhausted(
            generation,
            previousFailure,
            'Recovery exhausted its total attempt budget ($ceiling attempts).',
          );

          return;
        }

        var attemptedThisPass = false;

        for (final kind in plan) {
          if (!_isCurrent(generation)) {
            return;
          }

          if (kind == RecoveryStepKind.backoff) {
            continue;
          }

          final engine = _currentEngine(session);
          final step = _nextStep(kind, session, engine, sweptSources, triedBackends);

          if (step == null) {
            continue;
          }

          attemptedThisPass = true;

          final succeeded = await _runStep(step, session, generation);

          if (!_isCurrent(generation)) {
            return;
          }

          if (succeeded) {
            _finishCompleted(generation, step, previousFailure);

            return;
          }

          previousFailure = _lastStepFailure ?? previousFailure;

          // A backend swap inside this pass changed the engine: adopt it,
          // restore the FULL plan, and restart from the top so the new
          // engine gets its own reopen plus a full sweep of the line list.
          // The escalation that produced this swap condemned the previous
          // engine — it says nothing about the new one, and inheriting the
          // truncated plan would deny the new engine its reopen and lines.
          if (step.kind == RecoveryStepKind.nextBackend) {
            _adoptEngine(step.backendId ?? _currentEngine(session));

            if (!identical(plan, proposed)) {
              plan = proposed;
            }

            break;
          }
        }

        if (!_isCurrent(generation)) {
          return;
        }

        // Every dimension is spent: there is no rung left to climb, and
        // waiting would only delay the same answer.
        if (!attemptedThisPass) {
          _finishExhausted(generation, previousFailure, 'No recovery step remained available.');

          return;
        }

        if (!plan.contains(RecoveryStepKind.backoff) || backoffAttempt >= budget.maxBackoffAttempts) {
          _finishExhausted(generation, previousFailure, 'Recovery budget is exhausted.');

          return;
        }

        // The wait is a rung of its own, and it is the only one that
        // costs time instead of state: after it the ladder rescans from
        // the top, which is what gives a transient outage a chance to
        // clear without burning the whole budget in a tight loop.
        final wait = RecoveryStep.backoff(index: backoffAttempt, delay: budget.delayFor(backoffAttempt));

        backoffAttempt++;

        final continued = await _runBackoff(wait, session, generation);

        if (!_isCurrent(generation)) {
          return;
        }

        if (!continued) {
          _finishExhausted(generation, previousFailure, 'Recovery was cancelled while waiting to retry.');

          return;
        }
      }
    } catch (error) {
      // A failure inside the driver itself (a throwing policy or
      // candidate provider) must still end the run: leaving the status
      // at `running` would block every later report.
      _finishExhausted(generation, _lastStepFailure ?? failure, 'Recovery driver failed: $error');
    }
  }

  /// The engine recovery is currently working on.
  ///
  /// Before the first swap this is the backend the failure came from;
  /// afterwards it is whichever backend the last `nextBackend` attached.
  String _currentEngine(RecoverySession session) => _engine ?? session.backendId ?? '';

  /// Builds the next step of [kind] for [engine], or `null` when none is
  /// available.
  ///
  /// Budgets are per engine: each engine gets its own reopens and its own
  /// sweep of the line list. A source already tried *on this engine* is
  /// not offered again, so a candidate list of one cannot make the ladder
  /// spin — while the next engine still gets the full list.
  RecoveryStep? _nextStep(
    RecoveryStepKind kind,
    RecoverySession session,
    String engine,
    Map<String, Set<String>> sweptSources,
    Set<String> triedBackends,
  ) {
    final engineSteps = _stepCounts.putIfAbsent(engine, () => <RecoveryStepKind, int>{});
    final used = engineSteps[kind] ?? 0;

    if (used >= budget.limitFor(kind)) {
      return null;
    }

    switch (kind) {
      case RecoveryStepKind.sameBackendReopen:
        final source = session.source;

        if (source == null) {
          return null;
        }

        // The line this engine is on counts as tried as soon as it is
        // reopened: the sweep must move on, not reopen it forever.
        sweptSources.putIfAbsent(engine, () => <String>{}).add(source.id.value);

        return RecoveryStep.reopen(index: used, source: source);

      case RecoveryStepKind.nextLine:
        final swept = sweptSources.putIfAbsent(engine, () => <String>{});

        for (final candidate in session.sourceCandidates) {
          if (!swept.add(candidate.id.value)) {
            continue;
          }

          return RecoveryStep.nextLine(index: used, source: candidate);
        }

        return null;

      case RecoveryStepKind.nextBackend:
        for (final candidate in session.backendCandidates) {
          if (!triedBackends.add(candidate.id)) {
            continue;
          }

          return RecoveryStep.nextBackend(index: used, backendId: candidate.id);
        }

        return null;

      case RecoveryStepKind.backoff:
        return null;
    }
  }

  /// The engine the ladder is working on, once it has swapped.
  ///
  /// `null` means the engine is still the one the failure came from.
  String? _engine;

  /// Total attempts this run may spend.
  ///
  /// An explicit [RecoveryBudget.maxTotalAttempts] wins; otherwise the
  /// ceiling is derived from the actual shape of the run — every engine
  /// gets its reopens plus one sweep of every line, plus the waits — so a
  /// budget cannot accidentally cut an engine off before it has tried
  /// every line. The ceiling is a runaway guard, not the primary limit.
  int _totalCeiling(RecoverySession session) {
    if (budget.maxTotalAttempts > 0) {
      return budget.maxTotalAttempts;
    }

    final engines = 1 + session.backendCandidates.length;
    final lines = session.sourceCandidates.length + 1;
    final perEngine = budget.maxSameBackendAttempts + lines + 1;

    return perEngine * engines + budget.maxBackoffAttempts;
  }

  RecoveryFailure? _lastStepFailure;

  Future<bool> _runStep(RecoveryStep step, RecoverySession session, int generation) async {
    if (!target.isRecoveryAvailable) {
      return false;
    }

    final engine = _currentEngine(session);

    _stepCounts.putIfAbsent(engine, () => <RecoveryStepKind, int>{})[step.kind] =
        (_stepCounts[engine]![step.kind] ?? 0) + 1;
    _attempts++;

    _emit(RecoveryLadderStepStarted(step: step, attempt: _attempts, failure: _failure));

    MediaCoreLog.info(
      LogCategory.recovery,
      'ladder step $_attempts/$_ceilingLabel: ${step.label} [engine $engine]',
      fields: <String, Object?>{
        'kind': step.kind.name,
        'engine': engine,
        'targetBackend': step.backendId,
        'uri': step.source?.uri.toString(),
      },
    );

    try {
      // One entry point per physical operation: a backend swap is not a
      // reopen, and keeping them apart is what lets the target decide
      // whether the previous backend survives the attempt.
      if (step.kind == RecoveryStepKind.nextBackend) {
        await target.swapToForRecovery(step, session);
      } else {
        await target.reopenForRecovery(step, session);
      }

      _lastStepFailure = null;

      return true;
    } catch (error, stackTrace) {
      final failure = RecoveryFailure.fromMessage(
        '${step.label} failed: $error',
        error: error,
        stackTrace: stackTrace,
        source: RecoveryFailureSource.kernel,
        sourceId: session.source?.id,
        backendId: step.backendId ?? session.backendId,
        generationId: session.generationId,
      );

      _lastStepFailure = failure;

      MediaCoreLog.warning(
        LogCategory.recovery,
        'ladder step failed: ${step.label}',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{'attempt': _attempts, 'kind': step.kind.name, 'backend': step.backendId},
      );

      _emit(
        RecoveryLadderStepFailed(
          step: step,
          attempt: _attempts,
          failure: failure,
          error: error,
          stackTrace: stackTrace,
        ),
      );

      return false;
    }
  }

  Future<bool> _runBackoff(RecoveryStep step, RecoverySession session, int generation) async {
    final engine = _currentEngine(session);

    _stepCounts.putIfAbsent(engine, () => <RecoveryStepKind, int>{})[RecoveryStepKind.backoff] =
        (_stepCounts[engine]![RecoveryStepKind.backoff] ?? 0) + 1;
    _attempts++;

    _emit(RecoveryLadderStepStarted(step: step, attempt: _attempts, failure: _failure));

    if (step.delay <= Duration.zero) {
      return _isCurrent(generation);
    }

    final completer = Completer<bool>();

    _waiting = completer;
    _timer = Timer(step.delay, () {
      if (!completer.isCompleted) {
        completer.complete(true);
      }
    });

    final continued = await completer.future;

    _timer?.cancel();
    _timer = null;
    _waiting = null;

    return continued && _isCurrent(generation);
  }

  // ---------------------------------------------------------------------------
  // Terminal transitions
  // ---------------------------------------------------------------------------

  void _finishCompleted(int generation, RecoveryStep step, RecoveryFailure failure) {
    if (!_isCurrent(generation)) {
      return;
    }

    _status = RecoveryLadderStatus.completed;

    _recordStreak();

    MediaCoreLog.info(
      LogCategory.recovery,
      'ladder recovered via ${step.label} after $_attempts attempt(s)',
      fields: <String, Object?>{'backend': step.backendId, 'uri': step.source?.uri.toString()},
    );

    _emit(RecoveryLadderCompleted(step: step, attempt: _attempts, failure: failure));
  }

  void _finishExhausted(int generation, RecoveryFailure failure, String message) {
    if (!_isCurrent(generation)) {
      return;
    }

    _status = RecoveryLadderStatus.exhausted;

    MediaCoreLog.error(
      LogCategory.recovery,
      'ladder exhausted after $_attempts attempt(s): $message',
      fields: <String, Object?>{
        'code': failure.code.value,
        'message': failure.message,
        'backend': failure.backendId,
        'label': failure.uri ?? failure.sourceId?.value,
        'stepsByEngine': _stepCountsDescription,
        'budget': budget.toMap(),
      },
    );

    _emit(RecoveryLadderExhausted(attempt: _attempts, message: message, failure: failure));
  }

  /// Counts how often the setup that just recovered has done so recently.
  ///
  /// The count is read back on the next report for the same engine and
  /// source, where it raises the starting rung.
  void _recordStreak() {
    final session = _session;

    if (session == null) {
      return;
    }

    final key = _setupKey(session);
    final previous = _streaks[key];
    final now = clock.now();
    final expired = previous == null || now.difference(previous.at) > _repeatWindow;

    _streaks[key] = (count: expired ? 1 : previous.count + 1, at: now);

    final engine = session.backendId ?? '';
    final enginePrevious = _engineStalls[engine];
    final engineExpired = enginePrevious == null || now.difference(enginePrevious.at) > _repeatWindow;

    _engineStalls[engine] = (count: engineExpired ? 1 : enginePrevious.count + 1, at: now);

    MediaCoreLog.info(
      LogCategory.recovery,
      'recovery streak for $key is now ${_streaks[key]!.count} '
          '(engine $engine: ${_engineStalls[engine]!.count}/$_engineStallLimit stalls)',
      fields: <String, Object?>{
        'engine': session.backendId,
        'line': session.source?.id.value,
        'engineStalls': _engineStalls[engine]!.count,
        'windowSeconds': _repeatWindow.inSeconds,
      },
    );
  }

  /// Stops the current run without deciding anything.
  ///
  /// The in-flight step (if any) is not cancelled — a native backend call
  /// cannot be — but the driver's generation check makes its result
  /// unusable, which is the same guarantee the handle's own operation
  /// generations provide.
  void _abort(String reason) {
    final wasRunning = _status == RecoveryLadderStatus.running;

    _generation++;
    _releaseWait(continueRun: false);

    if (wasRunning) {
      MediaCoreLog.debug(
        LogCategory.recovery,
        'ladder cancelled after $_attempts attempt(s): $reason',
        fields: <String, Object?>{'stepsByEngine': _stepCountsDescription},
      );

      _emit(RecoveryLadderCancelled(attempt: _attempts, message: reason, failure: _failure));
    }

    _failure = null;
    _session = null;
    _engine = null;
    _ceiling = null;
    _attempts = 0;
    _lastStepFailure = null;
    _stepCounts.clear();
    _streaks.clear();
    _engineStalls.clear();
  }

  /// Completes a pending backoff wait, if there is one.
  void _releaseWait({required bool continueRun}) {
    final waiting = _waiting;

    if (waiting == null || waiting.isCompleted) {
      return;
    }

    _timer?.cancel();
    _timer = null;

    waiting.complete(continueRun);
  }

  void _onTargetEvent(RecoveryTargetEvent event) {
    if (_disposed || !event.aborted) {
      return;
    }

    // The target can no longer execute anything: stop escalating instead
    // of feeding steps into a handle that has already given up.
    _abort('Recovery target reported that it can no longer recover.');
  }

  /// Total attempts the current run may spend, for the step log line.
  int? _ceiling;

  String get _ceilingLabel => '${_ceiling ?? budget.maxTotalAttempts}';

  /// Per-engine attempt summary for the terminal log line.
  String get _stepCountsDescription {
    return _stepCounts.entries
        .map((entry) {
          final counts = entry.value.entries.map((count) => '${count.key.name}:${count.value}').join(' ');

          return '${entry.key.isEmpty ? '<initial>' : entry.key} [$counts]';
        })
        .join(' | ');
  }

  /// Records the engine a swap moved to, so its budgets and line sweep
  /// start fresh.
  void _adoptEngine(String backendId) {
    _engine = backendId;
  }

  bool _isCurrent(int generation) {
    return !_disposed && _status == RecoveryLadderStatus.running && generation == _generation;
  }

  void _emit(RecoveryLadderEvent event) {
    if (_events.isClosed) {
      return;
    }

    _events.add(event);
  }

  RecoveryState _recoveryState() {
    final action = switch (_status) {
      RecoveryLadderStatus.running => const RecoveryAction.retry(),
      RecoveryLadderStatus.completed => const RecoveryAction.retry(),
      RecoveryLadderStatus.exhausted => const RecoveryAction.stop(),
      _ => const RecoveryAction.none(),
    };

    return RecoveryState(
      action: action,
      attempt: _attempts,
      active: _status == RecoveryLadderStatus.running,
      completed: _status == RecoveryLadderStatus.completed,
      exhausted: _status == RecoveryLadderStatus.exhausted,
      updatedAt: clock.now(),
    );
  }

  @override
  String toString() {
    return 'RecoveryLadder(${_status.name}, attempt: $_attempts, budget: $budget)';
  }
}
