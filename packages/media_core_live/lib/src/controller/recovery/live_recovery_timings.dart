/// Deadlines and budgets of the live recovery machinery: the offline
/// (network-lost) state machine, the failure-handling ladder and the
/// stability window that clears its counters.
final class LiveRecoveryTimings {
  /// Creates the timings; every field has the live module's default.
  const LiveRecoveryTimings({
    this.offlineGrace = const Duration(seconds: 20),
    this.offlineProbeInterval = const Duration(seconds: 2),
    this.offlineProbeTimeout = const Duration(seconds: 5),
    this.recoveryBudgetReset = const Duration(seconds: 30),
    this.liveRetryDelays = const <Duration>[Duration(milliseconds: 750), Duration(seconds: 2)],
    this.refreshBudget = 2,
  });

  /// How long the offline state machine keeps announcing reconnects before
  /// it publishes the network-lost failure. Probing continues past it.
  final Duration offlineGrace;

  /// The pause between two looks at the network while it is gone.
  final Duration offlineProbeInterval;

  /// Longest wait for one look at the network.
  final Duration offlineProbeTimeout;

  /// Sustained playback that clears the recovery count and the ladder
  /// budgets.
  final Duration recoveryBudgetReset;

  /// Delays of the bounded retry rounds after the immediate ladder is
  /// exhausted; each round starts with fresh budgets.
  final List<Duration> liveRetryDelays;

  /// How many recovery source refreshes one budget window allows before
  /// the sweep runs on the lines it already holds.
  final int refreshBudget;
}
