import 'package:media_core/background/background_models.dart';
import 'package:meta/meta.dart';

/// The platform work a registry delegates to.
///
/// This is the seam between the contract and Android: the registry owns ids,
/// duplicate handling, state and who still holds what, while a backend only ever
/// talks to one session it was handed. Keeping the two apart is what lets the
/// lease rules be tested without a device — and what stops a business module
/// from starting a service of its own.
abstract interface class BackgroundExecutionBackend {
  /// What this platform can offer at all, before any request is checked.
  ///
  /// A capability missing here is answered with [BackgroundAcquireFailure.capabilityUnavailable]
  /// or [BackgroundAcquireFailure.unsupportedPlatform] instead of a session that
  /// quietly holds nothing.
  Set<BackgroundCapability> get supportedCapabilities;

  /// Starts protection for one session.
  ///
  /// Must not throw for a refusal the platform expects: a refusal is an answer,
  /// and [BackgroundBackendRefused] is where its reason goes.
  Future<BackgroundBackendOutcome> open(BackgroundRequest request);
}

/// One session a backend has started.
abstract interface class BackgroundBackendLease {
  /// Status the platform itself noticed.
  ///
  /// Broadcast, and it may end whenever the session does. A backend with nothing
  /// to report leaves it empty — the registry drives the lifecycle either way.
  Stream<BackgroundSessionStatus> get statusChanges;

  /// Replaces what the platform shows for this session.
  Future<void> update(BackgroundRequest request);

  /// Gives up what this session was started with. Only this session's.
  Future<void> release();
}

/// What a backend answered to an open.
sealed class BackgroundBackendOutcome {
  /// Creates an outcome.
  const BackgroundBackendOutcome();
}

/// The session is running on the platform.
final class BackgroundBackendGranted extends BackgroundBackendOutcome {
  /// Creates a granted outcome.
  const BackgroundBackendGranted(this.lease);

  /// The started session.
  final BackgroundBackendLease lease;
}

/// The platform said no, and this is the reason.
final class BackgroundBackendRefused extends BackgroundBackendOutcome {
  /// Creates a refused outcome.
  const BackgroundBackendRefused(this.reason, [this.message]);

  /// Why.
  final BackgroundAcquireFailure reason;

  /// Detail for the log.
  final String? message;
}

/// The media playback surface, as the background runtime sees it.
///
/// Playback is a session of its own, with its own service and its own control
/// surface, and it is not a `BackgroundExecutionKind`. This contract exists so
/// that separation is written down rather than implied: `media_core_mediasession`
/// implements it over `audio_service`, and nothing else activates a media
/// session.
///
/// The qualification for activating one is real playback — a playing transport,
/// an audio focus claim, a platform that allows background audio — and never a
/// side effect of the UI being ready. A surface that happens to exist is not a
/// reason for the system to keep a process alive.
abstract interface class MediaBackgroundSession {
  /// Makes [sessionId] the session the platform shows.
  ///
  /// Ownership moves: exactly one session holds the media surface at a time, and
  /// activating a second one takes it from the first rather than stacking a
  /// second control bar. The result says whether the platform actually took it —
  /// "we asked" is not "the viewer can see it".
  Future<MediaSessionActivation> activate({required String sessionId, required String title});

  /// Updates the title of the session that is showing.
  ///
  /// Ignored when [sessionId] no longer owns the surface, which is the race a
  /// multi-view switch produces: the old player's late callback must not rewrite
  /// the new player's control bar.
  Future<void> updateMetadata({required String sessionId, required String title});

  /// Gives up the surface, but only if [sessionId] still owns it.
  Future<void> deactivate(String sessionId);

  /// The session holding the surface, or null when nothing does.
  String? get activeSessionId;
}

/// Why a media session was not shown.
///
/// The three answers ask the host for three different actions, which is why they
/// are not one: retry later, tear the feature down, or give up on this driver.
enum MediaSessionRefusal {
  /// `initialize` has not run yet: there is no platform handshake to take a surface.
  ///
  /// The common one — a host that activates during startup, before
  /// `MediaSessionBootstrap.enable` finished. Waiting for it is the right answer.
  notInitialized,

  /// The platform has no surface to take: a web build, a desktop without SMTC or
  /// MPRIS, a device whose media service refused to start.
  ///
  /// `initialize` ran and did not produce a handler. Retrying will not help; this
  /// is what "no background media on this platform" looks like from the calling side.
  surfaceUnavailable,

  /// The driver was disposed, so its surface was released and will not be taken again.
  ///
  /// Distinct from [notInitialized] because the host's mistake is the opposite one:
  /// something is still calling a driver it already threw away, not a call that came
  /// too early.
  disposed,
}

/// What answering a media activation actually got the host.
@immutable
final class MediaSessionActivation {
  /// The surface is held by this session.
  const MediaSessionActivation.held({this.previousOwnerSessionId}) : reason = null;

  /// Nothing was shown, and this is why.
  const MediaSessionActivation.refused(this.reason) : previousOwnerSessionId = null;

  /// Whether the platform holds the surface for this session.
  bool get held => reason == null;

  /// Why it was refused, when it was.
  final MediaSessionRefusal? reason;

  /// The session this activation took the surface from, when there was one.
  ///
  /// Named because the host that loses the surface usually does not know it lost
  /// it: a multiview switch that silently leaves the old player's control bar up
  /// is a bug nobody can see from the new player's side.
  final String? previousOwnerSessionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaSessionActivation &&
          other.reason == reason &&
          other.previousOwnerSessionId == previousOwnerSessionId;

  @override
  int get hashCode => Object.hash(reason, previousOwnerSessionId);

  @override
  String toString() => held
      ? 'MediaSessionActivation.held(previous: $previousOwnerSessionId)'
      : 'MediaSessionActivation.refused(${reason!.name})';
}
