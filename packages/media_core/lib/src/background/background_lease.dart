import 'package:media_core/src/background/background_models.dart';

/// A session the runtime is holding for a job.
///
/// The handle is the release: a job holds one, and `try/finally` with
/// [release] is what keeps a notification and a wake lock from outliving the
/// work they were asked for.
abstract interface class BackgroundLease {
  /// The id the session was registered under.
  String get id;

  /// What the session is doing right now, as last known.
  BackgroundSessionStatus get status;

  /// Everything this session still holds.
  ///
  /// A subset of what was asked for: a platform that cannot post a notification
  /// grants the execution and drops that one capability rather than failing the
  /// job.
  Set<BackgroundCapability> get grantedCapabilities;

  /// The description this session currently carries.
  BackgroundRequest get request;

  /// Lifecycle transitions of this session.
  ///
  /// Broadcast, and it ends when the session is released. A runtime that can
  /// lose a capability mid-run (a timeout callback, a service killed by the
  /// system) reports it here rather than in the acquire result, which has
  /// already been returned.
  Stream<BackgroundSessionStatus> get statusChanges;

  /// Replaces what this session says about itself.
  ///
  /// Only this session's record changes; the other sessions in the aggregate are
  /// untouched. After [release] this is a no-op — a notification must not
  /// outlive the job that posted it.
  Future<void> update(BackgroundRequest request);

  /// Ends the session and gives up what it held. Idempotent.
  ///
  /// Releasing never touches another session's protection, and it is safe from a
  /// failure path as well as a stop path.
  Future<void> release();
}

/// The answer to an acquire.
///
/// Sealed because "null" was the bug: a caller could not tell an unsupported
/// platform from a permission the user declined, and both are things the host
/// says something about.
sealed class BackgroundAcquireResult {
  /// Creates a result.
  const BackgroundAcquireResult();

  /// Whether a session is being held.
  bool get isGranted;
}

/// The session is held.
final class BackgroundAcquireSuccess extends BackgroundAcquireResult {
  /// Creates a granted result.
  const BackgroundAcquireSuccess({required this.lease, required this.grantedCapabilities});

  /// The handle to release.
  final BackgroundLease lease;

  /// What this platform actually undertook to hold.
  final Set<BackgroundCapability> grantedCapabilities;

  @override
  bool get isGranted => true;

  @override
  String toString() =>
      'BackgroundAcquireSuccess(${lease.id}, ${grantedCapabilities.map((capability) => capability.name).join('|')})';
}

/// Nothing is held, and this says why.
final class BackgroundAcquireRejected extends BackgroundAcquireResult {
  /// Creates a refused result.
  const BackgroundAcquireRejected({required this.reason, this.message, this.duplicateOfId});

  /// Which kind of refusal.
  final BackgroundAcquireFailure reason;

  /// Detail for the log. Never shown to a user by this library, and no guarantee
  /// about what it says.
  final String? message;

  /// The id already held, when the refusal is about a duplicate.
  ///
  /// Worth naming: it is the caller's own key, and the only hint that two jobs
  /// were started for the same work.
  final String? duplicateOfId;

  @override
  bool get isGranted => false;

  @override
  String toString() => 'BackgroundAcquireRejected(${reason.name}, $message)';
}
