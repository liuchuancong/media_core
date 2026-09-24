import '../error/error_policy.dart';
import 'recovery_step.dart';
import 'recovery_session.dart';
import 'recovery_failure.dart';

/// Decides which rungs of the recovery ladder are available.
///
/// The ladder owns *how* steps are executed and in which order; the
/// policy owns *whether* a kind of step is appropriate for the failure
/// at hand. Keeping the two apart means an application can tighten
/// recovery behaviour without touching the ladder, and the ladder can
/// gain a step kind without every deployment changing behaviour.
///
/// Implementations must be side-effect free: the ladder may call
/// [plan] before it has decided to run anything.
abstract interface class RecoveryLadderPolicy {
  /// Ordered step kinds the ladder may attempt for [session]'s failure.
  ///
  /// The order is the escalation order. An empty result means the
  /// failure is terminal as far as the policy is concerned.
  List<RecoveryStepKind> plan(RecoveryFailure failure, RecoverySession session);
}

/// Default policy: delegates the entry decision to [ErrorPolicy].
///
/// Error classification already exists — it is the error module's job —
/// so recovery does not repeat it. This policy only translates the
/// error module's recommendation into a recovery escalation:
///
/// ```text
/// ErrorPolicyAction.retry      reopen → lines → backends → backoff
/// ErrorPolicyAction.recover    reopen → lines → backends → backoff
/// ErrorPolicyAction.fallback   lines → backends → backoff
/// ErrorPolicyAction.fail       (none)
/// ErrorPolicyAction.cancel     (none)
/// ErrorPolicyAction.ignore     (none)
/// ```
///
/// `fallback` skips the in-place reopen: the error module already
/// decided the current path is not worth replaying, so the ladder
/// starts at the next rung.
///
/// A source-level failure skips it as well, whatever the error module
/// recommended. "The URL cannot be opened" is a verdict on the
/// *source/engine pair*, not on the stream's current state, so reopening
/// the same URL on the same engine reproduces it — and on live streams
/// whose URLs carry a signed, short-lived token it cannot even succeed,
/// because the token has already been spent. Escalation starts at the
/// next line instead.
final class DefaultRecoveryLadderPolicy implements RecoveryLadderPolicy {
  /// Creates the default policy.
  ///
  /// [policy] overrides the error policy used for the entry decision.
  const DefaultRecoveryLadderPolicy({ErrorPolicy? policy}) : _policy = policy;

  final ErrorPolicy? _policy;

  static final ErrorPolicy _defaultPolicy = ErrorPolicy.defaults();

  /// Retry escalation: try the current path first.
  static const List<RecoveryStepKind> retryPlan = <RecoveryStepKind>[
    RecoveryStepKind.sameBackendReopen,
    RecoveryStepKind.nextLine,
    RecoveryStepKind.nextBackend,
    RecoveryStepKind.backoff,
  ];

  /// Fallback escalation: the current path is already spent.
  static const List<RecoveryStepKind> fallbackPlan = <RecoveryStepKind>[
    RecoveryStepKind.nextLine,
    RecoveryStepKind.nextBackend,
    RecoveryStepKind.backoff,
  ];

  /// No escalation at all.
  static const List<RecoveryStepKind> terminalPlan = <RecoveryStepKind>[];

  /// Error policy backing the entry decision.
  ErrorPolicy get errorPolicy => _policy ?? _defaultPolicy;

  @override
  List<RecoveryStepKind> plan(RecoveryFailure failure, RecoverySession session) {
    final action = errorPolicy.decide(failure.toFailure(), retryCount: session.attempt);

    return switch (action) {
      ErrorPolicyAction.retry => _planFor(failure, retryPlan),
      ErrorPolicyAction.recover => _planFor(failure, retryPlan),
      ErrorPolicyAction.fallback => fallbackPlan,
      ErrorPolicyAction.ignore => terminalPlan,
      ErrorPolicyAction.cancel => terminalPlan,
      ErrorPolicyAction.fail => terminalPlan,
    };
  }

  /// Drops the in-place reopen when the source itself is the problem.
  ///
  /// Kept separate from [ErrorPolicy] on purpose: the error module
  /// answers "is this retryable in general", which is a coarser question
  /// than "is replaying *this* URL on *this* engine worth an attempt".
  List<RecoveryStepKind> _planFor(RecoveryFailure failure, List<RecoveryStepKind> plan) {
    if (!failure.effectiveReason.isSource) {
      return plan;
    }

    return fallbackPlan;
  }

  @override
  String toString() => 'DefaultRecoveryLadderPolicy(errorPolicy: $errorPolicy)';
}
