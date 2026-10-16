import 'dart:async';

import 'package:media_core/src/background/background_backend.dart';
import 'package:media_core/src/background/background_lease.dart';
import 'package:media_core/src/background/background_models.dart';

/// The one door a job goes through to stay alive.
///
/// A business module declares a [BackgroundRequest] and releases the lease it
/// gets back; it never starts a service, takes a lock or posts a notification.
/// That is the point of the contract: the three mechanisms used to be reachable
/// from three packages at once, which is how one piece of work ended up holding
/// two foreground services and two notifications for the same job.
abstract interface class BackgroundRuntime {
  /// Starts holding background execution for [request].
  ///
  /// Does not throw for a refusal the platform expects, and does not return null
  /// for one either: the result says which [BackgroundAcquireFailure] it was,
  /// because a host answers "the user declined notifications" differently from
  /// "this platform has nothing that holds".
  Future<BackgroundAcquireResult> acquire(BackgroundRequest request);

  /// The sessions being held, in the order a notification would list them.
  ///
  /// Highest [BackgroundRequest.priority] first, then by arrival. This is the
  /// aggregate a projector draws from; the runtime itself draws nothing.
  List<BackgroundRequest> get activeRequests;

  /// Everything somebody is holding right now.
  ///
  /// A capability stays in here while at least one session holds it, which is
  /// what a caller checks before assuming the CPU may sleep.
  Set<BackgroundCapability> get activeCapabilities;

  /// Number of sessions held.
  int get activeSessionCount;

  /// The session registered under [id], or null.
  BackgroundLease? peek(String id);

  /// What this platform can offer at all, whether or not a session holds it.
  ///
  /// A projector asks this before drawing anything: a platform whose job service
  /// already shows a persistent notification per session does not need a second
  /// line saying the same thing, and one that shows nothing does.
  Set<BackgroundCapability> get platformCapabilities;

  /// Fires when the sessions held change, or when one of them changes what it
  /// says.
  ///
  /// Broadcast, and it carries no payload on purpose: the answer to "what should
  /// the line say now?" is [activeRequests], and an event that also tried to say
  /// it would be a second version of the same list to keep in step. A projector
  /// debounces this — the byte counter of a download is not a notification rate.
  ///
  /// One owner's change wakes every projector, not just its own; that is safe
  /// because a projector reads only `requestsFor(owner)` and reposts nothing when
  /// its own text did not change.
  Stream<void> get changes;
}

/// The runtime business modules go through.
///
/// Null until a platform package installs one, which is the same split the job
/// reporter slot uses: a host that links no backend keeps compiling and keeps
/// asking, and hears [BackgroundAcquireFailure.unsupportedPlatform] rather than
/// seeing a silent no-op.
abstract final class BackgroundRuntimes {
  /// The runtime a job asks protection from, or null when no platform package
  /// installed one. See `NativeBackgroundRuntime` in `media_core_native` for the
  /// channel-backed one.
  ///
  /// Assigning it is a startup act: a host installs the backend it links.
  /// Replacing a running registry takes no job's protection away, because the
  /// leases already handed out still release through the registry that created
  /// them.
  static BackgroundRuntime? get current => _current;

  static set current(BackgroundRuntime? value) {
    if (identical(_current, value)) {
      return;
    }

    _current = value;

    if (!_installed.isClosed) {
      _installed.add(value);
    }
  }

  static BackgroundRuntime? _current;

  /// Fires when [current] is assigned, including with null.
  ///
  /// A projector needs it because the ordering of a real app is not fixed: a host
  /// that enables notifications in `main()` before the first job installs its
  /// runtime would otherwise have to know to call `show()` twice. Waiting for the
  /// slot is what makes "enable it early" mean what it says.
  static Stream<BackgroundRuntime?> get changes => _installed.stream;

  static final StreamController<BackgroundRuntime?> _installed = StreamController<BackgroundRuntime?>.broadcast();

  /// Forgets the runtime. Used by a host tearing a process down, and by tests.
  static void reset() => current = null;
}

/// The per-owner view over a runtime's sessions.
///
/// An extension rather than an interface member: everything it answers is
/// already in [BackgroundRuntime.activeRequests], and a host writing its own test
/// runtime should not have to reimplement the filter to satisfy the contract.
extension BackgroundRuntimeOwners on BackgroundRuntime {
  /// The sessions held for one [owner], in the order a notification would list
  /// them — highest priority first, then by arrival.
  ///
  /// This is what lets each feature draw its own line: a recorder projects over
  /// its own sessions and nothing else, so a download starting or ending cannot
  /// change the text of the recording notification, and the last download to
  /// finish clears the download line only.
  List<BackgroundRequest> requestsFor(BackgroundServiceOwner owner) {
    final requests = activeRequests.where((request) => request.kind.serviceOwner == owner).toList(growable: false);

    return List<BackgroundRequest>.unmodifiable(requests);
  }
}

/// The Lease Registry, the policy engine and the session state machine.
///
/// A [BackgroundExecutionBackend] does a platform's work; this object keeps the
/// rules a platform cannot check for itself: one record per id, a duplicate id
/// handled by the policy the caller chose, a release that only ever releases
/// itself, and a capability that stays granted while somebody still holds it.
///
/// It is deliberately free of Android: every rule in §9 of the architecture note
/// is testable here without a device.
final class BackgroundLeaseRegistry implements BackgroundRuntime {
  /// Creates a runtime that delegates platform work to [backend].
  BackgroundLeaseRegistry({required BackgroundExecutionBackend backend}) : _backend = backend;

  final BackgroundExecutionBackend _backend;

  final Map<String, _Session> _sessions = <String, _Session>{};
  final Map<String, Future<BackgroundAcquireResult>> _opening = <String, Future<BackgroundAcquireResult>>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  List<BackgroundRequest> get activeRequests {
    final requests = _sessions.values.map((session) => session.request).toList(growable: true)
      ..sort((left, right) => right.priority.compareTo(left.priority));

    return List<BackgroundRequest>.unmodifiable(requests);
  }

  @override
  Set<BackgroundCapability> get activeCapabilities {
    final capabilities = <BackgroundCapability>{};

    for (final session in _sessions.values) {
      capabilities.addAll(session.granted);
    }

    return Set<BackgroundCapability>.unmodifiable(capabilities);
  }

  @override
  int get activeSessionCount => _sessions.length;

  @override
  Set<BackgroundCapability> get platformCapabilities => _backend.supportedCapabilities;

  @override
  Stream<void> get changes => _changes.stream;

  /// Gives up every session and stops announcing.
  ///
  /// A host tearing a process down, and a test that installed a registry of its
  /// own: the broadcast stream is the part that leaks quietly, because a
  /// projector holding it outlives everything it was watching.
  Future<void> dispose() async {
    for (final session in _sessions.values.toList(growable: false)) {
      await _release(session, exclusive: true);
    }

    await _changes.close();
  }

  /// Tells the projectors that the aggregate is no longer what they drew.
  ///
  /// Fired after the record is updated, never before: a projector that recomposes
  /// on the event must see the new list, not the one that was true a moment ago.
  void _changed() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  @override
  BackgroundLease? peek(String id) {
    final session = _sessions[id];

    return session == null ? null : _LeaseView(session, this, exclusive: true);
  }

  /// Whether some session still holds [capability].
  bool holds(BackgroundCapability capability) => activeCapabilities.contains(capability);

  @override
  Future<BackgroundAcquireResult> acquire(BackgroundRequest request) async {
    final problem = request.validationError();

    if (problem != null) {
      return BackgroundAcquireRejected(reason: BackgroundAcquireFailure.invalidRequest, message: problem);
    }

    // A request for an id that is still starting must see the first request's
    // answer, not a second opinion taken against a session that does not exist
    // yet. Without this the duplicate policy is checked against an empty registry
    // and two services start for one job.
    final opening = _opening[request.id];

    if (opening != null) {
      await opening.then<void>((_) {}, onError: (_) {});
      final result = await acquire(request);

      return result;
    }

    final existing = _sessions[request.id];

    if (existing != null) {
      final result = await _resolveDuplicate(existing, request);

      return result;
    }

    final rejection = _refuse(request);

    if (rejection != null) {
      return rejection;
    }

    final future = _open(request);
    _opening[request.id] = future;

    try {
      return await future;
    } finally {
      unawaited(_opening.remove(request.id));
    }
  }

  Future<BackgroundAcquireResult> _open(BackgroundRequest request) async {
    final granted = _capabilitiesFor(request);
    final session = _Session(id: request.id, request: request, granted: granted, registry: this);

    _sessions[request.id] = session;
    session.controller.add(BackgroundSessionStatus.starting);

    BackgroundBackendOutcome outcome;

    try {
      outcome = await _backend.open(request);
    } on Object catch (error, stackTrace) {
      return _failStart(
        session,
        BackgroundAcquireFailure.foregroundStartRejected,
        'the backend threw instead of refusing: $error',
        error,
        stackTrace,
      );
    }

    switch (outcome) {
      case BackgroundBackendRefused(:final BackgroundAcquireFailure reason, :final String? message):
        return _failStart(session, reason, message ?? 'the platform refused to start the session');

      case BackgroundBackendGranted(:final BackgroundBackendLease lease):
        session.backend = lease;

        if (session.pendingUpdate) {
          await lease.update(session.request);
          session.pendingUpdate = false;
        }

        // Released while the service was still starting: the job is over, and a
        // service that arrives after that must not be left running.
        if (session.released) {
          await lease.release();

          return BackgroundAcquireRejected(
            reason: BackgroundAcquireFailure.invalidRequest,
            message: 'session "${request.id}" was released before it started',
          );
        }

        lease.statusChanges.listen(
          session.applyBackendStatus,
          onError: session.reportBackendFailure,
          cancelOnError: false,
        );
        session.status = BackgroundSessionStatus.running;
        session.controller.add(BackgroundSessionStatus.running);
        _changed();

        return BackgroundAcquireSuccess(
          lease: _LeaseView(session, this, exclusive: true),
          grantedCapabilities: granted,
        );
    }
  }

  BackgroundAcquireResult _failStart(
    _Session session,
    BackgroundAcquireFailure reason,
    String? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _sessions.remove(session.id);
    _changed();
    session.status = BackgroundSessionStatus.failed;

    if (error != null && stackTrace != null) {
      session.controller.addError(error, stackTrace);
    }

    session.controller.add(BackgroundSessionStatus.failed);
    unawaited(session.controller.close());

    return BackgroundAcquireRejected(reason: reason, message: message);
  }

  Future<BackgroundAcquireResult> _resolveDuplicate(_Session session, BackgroundRequest request) async {
    switch (request.duplicatePolicy) {
      case BackgroundDuplicatePolicy.reject:
        return BackgroundAcquireRejected(
          reason: BackgroundAcquireFailure.invalidRequest,
          message: 'session "${request.id}" is already held and the request rejects a duplicate',
          duplicateOfId: request.id,
        );

      case BackgroundDuplicatePolicy.share:
        // A second owner gets a view of the same session. Releasing the view lets
        // go of the view, not of the other owner's protection — which is the
        // mistake the old silent reference counting made.
        return BackgroundAcquireSuccess(
          lease: _LeaseView(session, this, exclusive: false),
          grantedCapabilities: session.granted,
        );

      case BackgroundDuplicatePolicy.update:
        await _update(session, request);

        return BackgroundAcquireSuccess(
          lease: _LeaseView(session, this, exclusive: true),
          grantedCapabilities: session.granted,
        );
    }
  }

  Future<void> _update(_Session session, BackgroundRequest request) async {
    if (session.released) {
      return;
    }

    session.request = request;
    _changed();

    final backend = session.backend;

    if (backend == null) {
      // Still starting: the new description is applied as soon as the session
      // exists, and a job that updates before it has been granted is a job whose
      // latest words are the ones the notification should show.
      session.pendingUpdate = true;

      return;
    }

    await backend.update(request);
  }

  void _forget(_Session session) {
    if (_sessions.remove(session.id) != null) {
      _changed();
    }
  }

  Future<void> _release(_Session session, {required bool exclusive}) async {
    if (!exclusive) {
      return;
    }

    // A second release joins the one in flight rather than returning early: a
    // caller that awaits a release is told the platform is done, not that the
    // intent was noted.
    final inFlight = session.releasing;

    if (inFlight != null) {
      await inFlight;

      return;
    }

    if (session.released) {
      return;
    }

    session.released = true;
    _forget(session);

    final completion = session.releasing = _releaseNow(session);
    await completion;
  }

  Future<void> _releaseNow(_Session session) async {
    if (!session.controller.isClosed && session.status != BackgroundSessionStatus.stopping) {
      session.status = BackgroundSessionStatus.stopping;
      session.controller.add(BackgroundSessionStatus.stopping);
    }

    final backend = session.backend;

    if (backend == null) {
      // Nothing was started yet; [_open] releases the lease the moment it
      // arrives, because the session is already marked released.
      unawaited(session.controller.close());

      return;
    }

    try {
      await backend.release();
    } finally {
      if (session.status != BackgroundSessionStatus.failed) {
        session.status = BackgroundSessionStatus.stopped;

        if (!session.controller.isClosed) {
          session.controller.add(BackgroundSessionStatus.stopped);
        }
      }

      await session.controller.close();
    }
  }

  Set<BackgroundCapability> _capabilitiesFor(BackgroundRequest request) {
    final supported = _backend.supportedCapabilities;
    final granted = <BackgroundCapability>{};

    if (supported.contains(BackgroundCapability.foregroundExecution)) {
      granted.add(BackgroundCapability.foregroundExecution);
    }

    if (request.requiresCpuWakeLock && supported.contains(BackgroundCapability.cpuWakeLock)) {
      granted.add(BackgroundCapability.cpuWakeLock);
    }

    if (supported.contains(BackgroundCapability.persistentNotification)) {
      granted.add(BackgroundCapability.persistentNotification);
    }

    // backgroundAudio is never granted here: it belongs to the media session
    // backend, and a job lease that claimed it would be a second owner of one
    // surface.
    return Set<BackgroundCapability>.unmodifiable(granted);
  }

  BackgroundAcquireRejected? _refuse(BackgroundRequest request) {
    final supported = _backend.supportedCapabilities;

    if (supported.isEmpty) {
      return const BackgroundAcquireRejected(
        reason: BackgroundAcquireFailure.unsupportedPlatform,
        message: 'this platform has no background execution capability at all',
      );
    }

    // A wake lock is the one thing a job cannot trade away. A recording whose CPU
    // stops when the screen does is not a recording, so the request is refused
    // with a reason instead of granted with a hole in it.
    if (request.requiresCpuWakeLock && !supported.contains(BackgroundCapability.cpuWakeLock)) {
      return BackgroundAcquireRejected(
        reason: BackgroundAcquireFailure.capabilityUnavailable,
        message: 'this platform cannot keep the CPU awake, which "${request.id}" requires',
      );
    }

    return null;
  }
}

/// One session the registry holds.
class _Session {
  _Session({required this.id, required this.request, required this.granted, required this.registry});

  final String id;
  final Set<BackgroundCapability> granted;
  final BackgroundLeaseRegistry registry;
  final StreamController<BackgroundSessionStatus> controller = StreamController<BackgroundSessionStatus>.broadcast();

  BackgroundRequest request;
  BackgroundBackendLease? backend;
  BackgroundSessionStatus status = BackgroundSessionStatus.starting;
  bool released = false;
  bool pendingUpdate = false;
  Future<void>? releasing;

  /// A status the platform noticed on its own.
  ///
  /// A service the system tore down leaves the registry with it: a capability
  /// nobody holds any more must not keep counting as held, or the next caller
  /// reads "the CPU is awake" out of a dead session.
  void applyBackendStatus(BackgroundSessionStatus status) {
    switch (status) {
      case BackgroundSessionStatus.failed:
      case BackgroundSessionStatus.stopped:
        registry._forget(this);
        this.status = status;

        // A release that already closed this controller has no listener left to
        // tell; the platform tearing the session down afterwards is not a new
        // fact, and throwing here would land in a stream nobody is reading.
        if (!controller.isClosed) {
          controller.add(status);
          unawaited(controller.close());
        }

      case BackgroundSessionStatus.degraded:
      case BackgroundSessionStatus.running:
      case BackgroundSessionStatus.starting:
      case BackgroundSessionStatus.stopping:
        if (this.status != status && !controller.isClosed) {
          this.status = status;
          controller.add(status);
        }
    }
  }

  void reportBackendFailure(Object error, StackTrace stackTrace) => controller.addError(error, stackTrace);
}

/// The handle a job holds.
///
/// Whether this handle is the owner that acquired the session, or a second
/// reader given it by the share policy. Only an owner ends the session on
/// release.
class _LeaseView implements BackgroundLease {
  _LeaseView(this._session, this._registry, {required bool exclusive}) : _exclusive = exclusive;

  final _Session _session;
  final BackgroundLeaseRegistry _registry;
  final bool _exclusive;

  @override
  String get id => _session.id;

  @override
  BackgroundSessionStatus get status => _session.status;

  @override
  Set<BackgroundCapability> get grantedCapabilities => _session.granted;

  @override
  BackgroundRequest get request => _session.request;

  @override
  Stream<BackgroundSessionStatus> get statusChanges => _session.controller.stream;

  @override
  Future<void> update(BackgroundRequest request) async {
    if (_session.released || request.id != _session.id) {
      return;
    }

    final problem = request.validationError();

    if (problem != null) {
      return;
    }

    _session.request = request;

    final backend = _session.backend;

    if (backend == null) {
      _session.pendingUpdate = true;

      return;
    }

    _registry._changed();
    await backend.update(request);
  }

  @override
  Future<void> release() => _registry._release(_session, exclusive: _exclusive);

  @override
  String toString() => '_LeaseView(${_session.id}, ${_exclusive ? 'owner' : 'shared'}, ${_session.status.name})';
}
