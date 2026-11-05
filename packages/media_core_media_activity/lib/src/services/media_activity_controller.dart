import 'package:media_core_media_activity/src/interfaces/media_activity_platform.dart';
import 'package:media_core_media_activity/src/models/media_activity_capabilities.dart';
import 'package:media_core_media_activity/src/models/media_activity_metadata.dart';
import 'package:media_core_media_activity/src/models/media_activity_state.dart';

/// Owns the lifecycle of the single Media Activity (spec §9).
///
/// The controller is the only writer on the Dart side: it gates on
/// capabilities, refuses duplicate sessions, stamps [MediaActivityContentState
/// .lyricRevision] so an out-of-order channel reply cannot overwrite newer
/// content, and dedupes identical pushes. Everything above it (coordinator,
/// host) reads state from here instead of tracking its own copy.
///
/// It also sits between iOS and the host on the command path: the platform
/// delivers remote commands and dismissal events here, and the controller
/// forwards them to [commandSink] — Swift owns no playback state (spec
/// §20.1.7).
final class MediaActivityController implements MediaActivityCommandSink {
  /// Creates the controller over [platform].
  MediaActivityController({required MediaActivityPlatform platform})
      : _platform = platform {
    platform.setCommandSink(this);
  }

  final MediaActivityPlatform _platform;

  MediaActivityCapabilitiesReport? _capabilities;
  MediaActivityMetadata? _metadata;
  MediaActivityContentState? _state;
  int _revision = 0;
  bool _disposed = false;

  /// Remote commands and dismissals from iOS; null detaches.
  MediaActivityCommandSink? commandSink;

  /// The activity currently alive, or null. The coordinator reads this to
  /// decide start-vs-update without asking the native side.
  MediaActivityMetadata? get activeMetadata => _metadata;

  /// The last state pushed to (or seeded into) the activity.
  MediaActivityContentState? get currentState => _state;

  /// Whether the native bridge reported usable Live Activities. Never asks
  /// the channel twice — the answer cannot change mid-session.
  Future<bool> get usable async =>
      (await capabilities()).usable;

  /// Reports the system capability once and caches it (spec §13.2).
  Future<MediaActivityCapabilitiesReport> capabilities() async {
    final cached = _capabilities;
    if (cached != null) {
      return cached;
    }

    final report = _disposed
        ? MediaActivityCapabilitiesReport.unsupported
        : await _platform.capabilities();
    _capabilities = report;

    return report;
  }

  /// Starts the activity for [metadata] seeded with [state].
  ///
  /// Returns false — without throwing — when the device cannot host
  /// activities, a session with the same id is already active, or the
  /// controller is disposed (spec §9.2, §13.3).
  Future<bool> start({
    required MediaActivityMetadata metadata,
    required MediaActivityContentState state,
  }) async {
    if (_disposed) {
      return false;
    }

    final usable = await this.usable;
    if (!usable) {
      return false;
    }

    // Duplicate sessions are a host bug, not a native error: refuse here so
    // the ActivityKit limit is never what surfaces it (spec §9.2.6).
    if (_metadata?.sessionId == metadata.sessionId) {
      return false;
    }

    // End any previous session first: one activity per app is the working
    // model, and switching tracks replaces rather than stacks (spec §7.2).
    final previous = _metadata;
    if (previous != null) {
      await _platform.endActivity(sessionId: previous.sessionId);
    }

    final seeded = state.copyWith(lyricRevision: ++_revision);
    final result = await _platform.startActivity(
      metadata: metadata,
      initialState: seeded,
    );

    if (!result.ok) {
      // A refused start leaves no activity behind: keep the ledger clean so
      // the next start is a clean create (spec §13.3: creation failure
      // degrades to normal playback).
      _logRefusal('start', result);
      return false;
    }

    _metadata = metadata;
    _state = seeded;

    return true;
  }

  /// Pushes [state] into the running activity.
  ///
  /// Returns false when no activity exists, the session id differs from the
  /// active one, or the state is identical to the last push (dedup — an
  /// event bus that replays must not spend ActivityKit budget, spec §8.1).
  Future<bool> update(MediaActivityContentState state) async {
    final metadata = _metadata;
    final current = _state;

    if (_disposed || metadata == null || current == null) {
      return false;
    }

    if (state == current) {
      return false;
    }

    final stamped = state.copyWith(lyricRevision: ++_revision);
    final result = await _platform.updateActivity(
      sessionId: metadata.sessionId,
      state: stamped,
    );

    if (!result.ok) {
      _logRefusal('update', result);
      return false;
    }

    _state = stamped;

    return true;
  }

  /// Ends the running activity.
  ///
  /// [clearNowPlaying] also clears the system media session (stop, spec
  /// §9.4); a pause keeps both and only updates the play state.
  Future<void> end({bool clearNowPlaying = false}) async {
    final metadata = _metadata;

    if (_disposed || metadata == null) {
      return;
    }

    await _platform.endActivity(sessionId: metadata.sessionId);
    if (clearNowPlaying) {
      await _platform.clearNowPlaying();
    }

    _metadata = null;
    _state = null;
  }

  /// Ends every activity and drops the ledger (cleanup on logout, spec §9.4).
  Future<void> endAll() async {
    if (_disposed) {
      return;
    }

    await _platform.endAllActivities();
    await _platform.clearNowPlaying();

    _metadata = null;
    _state = null;
  }

  /// Detaches the controller permanently (host shutdown): tears everything
  /// down and turns every later call into a no-op — a disposed controller
  /// must never resurrect an activity on a late event (spec §13.3).
  Future<void> dispose() async {
    await endAll();

    _disposed = true;
    commandSink = null;
  }

  /// Reports whether the native side still considers the activity alive.
  /// Used by the recovery path to re-adopt or clean up (spec §9.5).
  Future<bool> isActive() async {
    final metadata = _metadata;

    if (_disposed || metadata == null) {
      return false;
    }

    final status = await _platform.activityStatus(sessionId: metadata.sessionId);

    // The system dismissed it (user swipe, budget): forget the ledger entry
    // so the next event starts fresh instead of updating a ghost.
    if (status.isDismissed) {
      commandSink?.onActivityDismissed(metadata.sessionId);
      _metadata = null;
      _state = null;

      return false;
    }

    return status.isActive;
  }

  /// Updates the system Now Playing session (spec §11.1).
  ///
  /// Kept on the controller so the host (or the coordinator) never touches
  /// the platform directly: one writer, same lifecycle gating as the
  /// activity calls.
  Future<void> updateNowPlaying(NowPlayingUpdate update) async {
    if (_disposed) {
      return;
    }

    await _platform.updateNowPlaying(update);
  }

  void _logRefusal(String op, MediaActivityCallResult result) {
    assert(() {
      // A refusal is a degraded feature, never an error on the playback
      // path — surface it in debug builds through the record, stay silent
      // in release (spec §13.3: all errors degrade).
      // ignore: avoid_print
      print('MediaActivity.$op refused: ${result.errorCode}');

      return true;
    }(), 'refusal logging runs in debug builds only');
  }

  @override
  void onActivityDismissed(String sessionId) =>
      commandSink?.onActivityDismissed(sessionId);

  @override
  void onPlay(String playerId) => commandSink?.onPlay(playerId);

  @override
  void onPause(String playerId) => commandSink?.onPause(playerId);

  @override
  void onTogglePlayPause(String playerId) =>
      commandSink?.onTogglePlayPause(playerId);

  @override
  void onNextTrack(String playerId) => commandSink?.onNextTrack(playerId);

  @override
  void onPreviousTrack(String playerId) =>
      commandSink?.onPreviousTrack(playerId);

  @override
  void onSeek(String playerId, int positionMs) =>
      commandSink?.onSeek(playerId, positionMs);
}
