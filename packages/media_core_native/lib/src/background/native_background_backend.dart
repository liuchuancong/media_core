import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:media_core/media_core.dart'
    show
        BackgroundAcquireFailure,
        BackgroundBackendGranted,
        BackgroundBackendLease,
        BackgroundBackendOutcome,
        BackgroundBackendRefused,
        BackgroundCapability,
        BackgroundExecutionBackend,
        BackgroundExecutionKind,
        BackgroundJobProgress,
        BackgroundLeaseRegistry,
        BackgroundRequest,
        BackgroundRuntime,
        BackgroundRuntimes,
        BackgroundServiceOwner,
        BackgroundSessionStatus;
import 'package:media_core_native/src/background/background_execution.dart'
    show
        BackgroundExecution,
        BackgroundExecutionLease,
        BackgroundExecutionRefusal,
        BackgroundExecutionStatus,
        BackgroundJobKind,
        BackgroundNotification,
        BackgroundProgress,
        BackgroundServiceTarget;

/// The Android/iOS/macOS/Windows side of the background runtime contract.
///
/// This is the only place the contract touches the platform channel. It starts the
/// foreground service for the request's own feature, holds that feature's wake
/// lock and updates that feature's notification through [BackgroundExecution];
/// everything above it — which id means what, who still holds the CPU, whether a
/// second request for one job is a duplicate — stays in the registry, where it can
/// be tested without a device.
///
/// The owner → target mapping is this file's own decision point: the contract says
/// which feature a request belongs to, and the wire spelling is the channel's.
/// Keeping the table here is what makes the two vocabularies drift visibly instead
/// of silently.
///
/// What it deliberately does not do: decide what a feature's aggregate
/// notification looks like, and compute reference counts. The Java service already
/// does both per feature, and doing them again here would give one job two owners
/// of the same lock.
final class NativeBackgroundBackend implements BackgroundExecutionBackend {
  /// Creates the backend. Stateless: the channel is a singleton.
  const NativeBackgroundBackend();

  @override
  Set<BackgroundCapability> get supportedCapabilities => _capabilitiesFor(defaultTargetPlatform);

  @override
  Future<BackgroundBackendOutcome> open(BackgroundRequest request) async {
    final attempt = await BackgroundExecution.acquireDetailed(
      notification: notificationFor(request),
      target: targetFor(request.kind.serviceOwner),
      wakeLock: request.requiresCpuWakeLock,
    );

    final session = attempt.session;

    if (session == null) {
      return BackgroundBackendRefused(
        _failureFor(attempt.refusal),
        'the platform gave no session (${attempt.refusal?.name})',
      );
    }

    // iOS only: the bounded task assertion covers the transition to the
    // background, and the silent keep-alive covers the hours after it. Every
    // other platform answers without a round trip, so this is unconditional
    // on purpose.
    final keepAlive = await BackgroundExecution.acquireAudioKeepAlive();

    return BackgroundBackendGranted(_NativeBackendLease(session, keepAliveHeld: keepAlive));
  }

  /// The words the platform shows for [request].
  ///
  /// Public because a host that speaks the channel directly — its own backend, a
  /// migration still in progress — has to send the same shape, or the two paths
  /// draw two different notifications for one job.
  static BackgroundNotification notificationFor(BackgroundRequest request) {
    return BackgroundNotification(
      title: request.title,
      text: request.description,
      kind: switch (request.kind) {
        BackgroundExecutionKind.recording => BackgroundJobKind.record,
        BackgroundExecutionKind.download => BackgroundJobKind.download,
        BackgroundExecutionKind.generic => BackgroundJobKind.task,
      },
      icon: request.icon,
      progress: switch (request.progress) {
        final BackgroundJobProgress progress when progress.isIndeterminate => const BackgroundProgress.indeterminate(),
        final BackgroundJobProgress progress => BackgroundProgress.determinate(
          current: progress.current ?? 0,
          total: progress.total,
        ),
        null => null,
      },
    );
  }

  /// Which foreground service holds a session for [owner].
  ///
  /// Playback never reaches this backend — it is not a job kind, and the media
  /// session has its own service and its own notification — so
  /// [BackgroundServiceOwner.mediaSession] here is a caller that routed a request
  /// through the wrong door. Saying so beats parking playback on the download
  /// service with a label that describes neither.
  static BackgroundServiceTarget targetFor(BackgroundServiceOwner owner) {
    return switch (owner) {
      BackgroundServiceOwner.recording => BackgroundServiceTarget.recording,
      BackgroundServiceOwner.download => BackgroundServiceTarget.download,
      BackgroundServiceOwner.genericJob => BackgroundServiceTarget.generic,
      BackgroundServiceOwner.mediaSession => throw UnsupportedError(
        'media playback is not a job session: it belongs to the media session service',
      ),
    };
  }

  static BackgroundAcquireFailure _failureFor(BackgroundExecutionRefusal? refusal) {
    return switch (refusal) {
      BackgroundExecutionRefusal.serviceRefused => BackgroundAcquireFailure.foregroundStartRejected,
      BackgroundExecutionRefusal.unsupportedPlatform ||
      BackgroundExecutionRefusal.pluginMissing ||
      BackgroundExecutionRefusal.noPlatformBinding => BackgroundAcquireFailure.unsupportedPlatform,
      null => BackgroundAcquireFailure.foregroundStartRejected,
    };
  }

  /// What each platform's plugin actually implements.
  ///
  /// | platform | mechanism |
  /// | --- | --- |
  /// | Android | the feature's own foreground service (`specialUse` for recording, `dataSync` for the rest) + its own `PARTIAL_WAKE_LOCK` + its own persistent notification |
  /// | iOS | a background task assertion (bounded) + an optional silent audio keep-alive: with the app's `audio` background mode declared and the session active, the process is not suspended for as long as the job runs |
  /// | macOS | a sleep assertion held until the last session ends |
  /// | Windows | `SetThreadExecutionState(ES_SYSTEM_REQUIRED)` |
  /// | Linux, web | nothing yet; every request comes back [BackgroundAcquireFailure.unsupportedPlatform] |
  ///
  /// iOS, macOS and Windows report [BackgroundCapability.cpuWakeLock] because
  /// their one mechanism does keep the work running with the display off — but
  /// no platform's answer survives the process being killed, and on iOS the
  /// unbounded part additionally needs the app's `audio` background mode: the
  /// backend starts the silent keep-alive beside every job session and the
  /// keep-alive reports honestly when the declaration is missing. A grant is
  /// an undertaking, not a guarantee.
  static Set<BackgroundCapability> _capabilitiesFor(TargetPlatform platform) {
    if (kIsWeb) {
      return const <BackgroundCapability>{};
    }

    return switch (platform) {
      TargetPlatform.android => const <BackgroundCapability>{
        BackgroundCapability.foregroundExecution,
        BackgroundCapability.cpuWakeLock,
        BackgroundCapability.persistentNotification,
      },
      TargetPlatform.iOS || TargetPlatform.macOS || TargetPlatform.windows => const <BackgroundCapability>{
        BackgroundCapability.foregroundExecution,
        BackgroundCapability.cpuWakeLock,
      },
      _ => const <BackgroundCapability>{},
    };
  }
}

/// One session the channel is holding.
class _NativeBackendLease implements BackgroundBackendLease {
  _NativeBackendLease(this._session, {required bool keepAliveHeld}) : _keepAliveHeld = keepAliveHeld;

  final BackgroundExecutionLease _session;

  /// Whether the iOS silent keep-alive was granted beside this session; only
  /// then does releasing it below send the counterpart call.
  final bool _keepAliveHeld;

  /// The platform's own reports about this session, and nothing else's.
  ///
  /// Filtering by the handle `acquire` issued is the whole of it: a timeout that
  /// ended the recording service must not be read as news about a download, which
  /// is the same isolation the per-feature services were split for.
  @override
  Stream<BackgroundSessionStatus> get statusChanges =>
      BackgroundExecution.statusFor(_session.id).map((report) => _statusFor(report.status));

  static BackgroundSessionStatus _statusFor(BackgroundExecutionStatus status) => switch (status) {
    BackgroundExecutionStatus.degraded => BackgroundSessionStatus.degraded,
    BackgroundExecutionStatus.stopped => BackgroundSessionStatus.stopped,
    BackgroundExecutionStatus.protectionLost => BackgroundSessionStatus.protectionLost,
  };

  @override
  Future<void> update(BackgroundRequest request) => _session.update(NativeBackgroundBackend.notificationFor(request));

  @override
  Future<void> release() async {
    if (_keepAliveHeld) {
      // The native side reference counts, so two sessions releasing in either
      // order keep the survivor's audio alive.
      await BackgroundExecution.releaseAudioKeepAlive();
    }

    await _session.release();
  }
}

/// The runtime every job in this process shares.
abstract final class NativeBackgroundRuntime {
  /// The installed runtime, creating the native one on first use.
  ///
  /// A host that wants its own registry — a fake in a test, an aggregator of its
  /// own — assigns [BackgroundRuntimes.current] before the first job starts and
  /// this returns that instead.
  static BackgroundRuntime get shared =>
      BackgroundRuntimes.current ??= BackgroundLeaseRegistry(backend: const NativeBackgroundBackend());
}
