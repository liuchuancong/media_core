/// What a session may do after its device goes quiet (§20.4).
///
/// The default follows the doc's initial engineering policy: recovery
/// is automatic but bounded — re-resolve the device, rebuild its
/// services, re-arm eventing, probe, and only then call the session
/// connected again. Media is never re-pushed without confirmation (a
/// recovery that answers "the TV is still playing" must not restart
/// the film); after [maxAttempts] the session fails and the host
/// decides.
final class DlnaRecoveryPolicy {
  /// Creates a policy.
  const DlnaRecoveryPolicy({this.enabled = true, this.maxAttempts = 3, this.retryDelay = const Duration(seconds: 2)});

  /// A policy that never recovers: the first network failure fails the
  /// session.
  const DlnaRecoveryPolicy.disabled() : enabled = false, maxAttempts = 0, retryDelay = Duration.zero;

  /// Whether automatic recovery runs at all.
  final bool enabled;

  /// How many recovery attempts run before the session fails.
  final int maxAttempts;

  /// The pause between attempts (applied from the second on).
  final Duration retryDelay;
}
