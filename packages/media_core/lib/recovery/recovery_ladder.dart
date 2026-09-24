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

  final Map<RecoveryStepKind, int> _stepCounts = <RecoveryStepKind, int>{};

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

  /// Number of steps executed in the current (or last) run.
  int get attempt => _attempts;

  /// Steps executed per kind in the current (or last) run.
  Map<RecoveryStepKind, int> get stepCounts => Map<RecoveryStepKind, int>.unmodifiable(_stepCounts);

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
              metadata: <String, Object?>{'reporter': current.source.name, 'step': _stepCounts.toString()},
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

    _status = RecoveryLadderStatus.running;
    _failure = failure;
    _attempts = 0;
    _stepCounts.clear();
    _run = _drive(failure, generation);

    return true;
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

  Future<void> _drive(RecoveryFailure failure, int generation) async {
    try {
      if (!target.isRecoveryAvailable) {
        _finishExhausted(generation, failure, 'Recovery target is not available.');

        return;
      }

      final session = target.buildRecoverySession(failure, candidates.candidatesFor(failure));

      _session = session;

      final plan = policy.plan(failure, session);

      _emit(RecoveryLadderStarted(failure: failure, plan: plan, budget: budget));

      MediaCoreLog.info(
        LogCategory.recovery,
        'ladder started: ${plan.isEmpty ? '<no step allowed>' : plan.map((kind) => kind.name).join(' -> ')}',
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

      final triedSources = <String>{
        if (session.source != null) session.source!.id.value,
      };
      final triedBackends = <String>{
        if (session.backendId != null) session.backendId!,
      };

      var backoffAttempt = 0;
      var previousFailure = failure;

      while (_isCurrent(generation)) {
        if (_attempts >= budget.maxTotalAttempts) {
          _finishExhausted(generation, previousFailure, 'Recovery exhausted its total attempt budget.');

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

          final step = _nextStep(kind, session, triedSources, triedBackends);

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

        final continued = await _runBackoff(wait, generation);

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

  /// Builds the next step of [kind], or `null` when none is available.
  ///
  /// A source or backend that was already tried is not offered twice, so
  /// a candidate list of one cannot make the ladder spin.
  RecoveryStep? _nextStep(
    RecoveryStepKind kind,
    RecoverySession session,
    Set<String> triedSources,
    Set<String> triedBackends,
  ) {
    final used = _stepCounts[kind] ?? 0;

    if (used >= budget.limitFor(kind)) {
      return null;
    }

    switch (kind) {
      case RecoveryStepKind.sameBackendReopen:
        final source = session.source;

        if (source == null) {
          return null;
        }

        return RecoveryStep.reopen(index: used, source: source);

      case RecoveryStepKind.nextLine:
        for (final candidate in session.sourceCandidates) {
          if (!triedSources.add(candidate.id.value)) {
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

  RecoveryFailure? _lastStepFailure;

  Future<bool> _runStep(RecoveryStep step, RecoverySession session, int generation) async {
    if (!target.isRecoveryAvailable) {
      return false;
    }

    _stepCounts[step.kind] = (_stepCounts[step.kind] ?? 0) + 1;
    _attempts++;

    _emit(RecoveryLadderStepStarted(step: step, attempt: _attempts, failure: _failure));

    MediaCoreLog.info(
      LogCategory.recovery,
      'ladder step $_attempts/${budget.maxTotalAttempts}: ${step.label}',
      fields: <String, Object?>{'kind': step.kind.name, 'backend': step.backendId, 'uri': step.source?.uri.toString()},
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

  Future<bool> _runBackoff(RecoveryStep step, int generation) async {
    _stepCounts[RecoveryStepKind.backoff] = (_stepCounts[RecoveryStepKind.backoff] ?? 0) + 1;
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
        'steps': _stepCounts.map((kind, count) => MapEntry(kind.name, count)),
        'budget': budget.toMap(),
      },
    );

    _emit(RecoveryLadderExhausted(attempt: _attempts, message: message, failure: failure));
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
        fields: <String, Object?>{'steps': _stepCounts.map((kind, count) => MapEntry(kind.name, count))},
      );

      _emit(RecoveryLadderCancelled(attempt: _attempts, message: reason, failure: _failure));
    }

    _failure = null;
    _session = null;
    _attempts = 0;
    _lastStepFailure = null;
    _stepCounts.clear();
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
