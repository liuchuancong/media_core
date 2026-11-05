import 'package:media_core_media_activity/src/interfaces/media_activity_platform.dart';
import 'package:media_core_media_activity/src/models/media_activity_metadata.dart';
import 'package:media_core_media_activity/src/models/media_activity_state.dart';
import 'package:media_core_media_activity/src/services/media_activity_controller.dart';
import 'package:media_core_media_activity/src/services/media_activity_sync_policy.dart';

/// The event-driven entry point a host talks to (spec §8).
///
/// The host feeds it typed events — track changed, lyric boundary crossed,
/// play state flipped, seek landed, artwork landed — and the coordinator
/// turns them into the minimal sequence of native calls. It never receives
/// ordinary playback progress: the lock screen advances its own clock
/// between updates, and pushing position ticks is what the sync policy
/// exists to prevent (spec §8.1).
///
/// Lyrics that only matter while paused stay caller-side: when nothing is
/// playing the coordinator stops pushing lyric updates entirely (spec §9.4).
final class MediaActivityCoordinator {
  /// Creates the coordinator over [controller] and [policy].
  MediaActivityCoordinator({
    required MediaActivityController controller,
    this.policy = const MediaActivitySyncPolicy(),
    this.playerId = '',
  }) : _controller = controller;

  final MediaActivityController _controller;

  /// The cadence authority (spec §8.4).
  final MediaActivitySyncPolicy policy;

  /// Player id echoed back on remote commands, so a multi-player host can
  /// route. Empty string for single-player hosts.
  final String playerId;

  /// The latest static attributes; kept so merged artwork/metadata changes
  /// fold into the next push with the right identity (spec §8.4).
  MediaActivityMetadata? _metadata;

  /// The latest dynamic content the coordinator knows about.
  MediaActivityContentState? _state;

  /// Pending merged changes (artwork/metadata) awaiting the next push.
  bool _mergedPending = false;

  /// Starts (or restarts) the activity for [metadata].
  ///
  /// A different session id replaces the current activity (spec §7.2); the
  /// same id only re-seeds content when the activity died underneath us
  /// (recovery, spec §9.5).
  Future<void> onTrackChanged(
    MediaActivityMetadata metadata,
    MediaActivityContentState state,
  ) async {
    final previous = _metadata;
    final sameSession = previous?.sessionId == metadata.sessionId;

    if (sameSession && await _controller.isActive()) {
      // Same track re-announced after a recovery: refresh content only.
      _metadata = metadata;
      _state = state;
      await _push(reason: MediaActivityUpdateReason.recovery);

      return;
    }

    if (!sameSession) {
      await _controller.end(clearNowPlaying: true);
    }

    _metadata = metadata;
    _state = state;
    _mergedPending = false;

    // Start decisions are the controller's: it refuses duplicates and
    // unsupported devices without the coordinator caring (spec §9.2).
    await _controller.start(metadata: metadata, state: state);
    await _syncNowPlaying();
  }

  /// A lyric boundary was crossed: [currentLyric] is on screen now,
  /// [nextLyric] follows.
  ///
  /// Skipped while paused — a paused activity keeps its last lyric (spec
  /// §9.4) — and skipped when the lines are identical (an event bus that
  /// replays must not spend ActivityKit budget).
  Future<void> onLyricChanged({
    required String currentLyric,
    String nextLyric = '',
  }) async {
    final state = _state;

    if (state == null || !state.isPlaying) {
      return;
    }

    if (state.currentLyric == currentLyric && state.nextLyric == nextLyric) {
      return;
    }

    _state = state.copyWith(currentLyric: currentLyric, nextLyric: nextLyric);
    await _push(reason: MediaActivityUpdateReason.lyricChanged);
  }

  /// Play/pause/rate changed (never ordinary progress — that has no event
  /// here on purpose, spec §8.1).
  Future<void> onPlaybackChanged({
    required bool isPlaying,
    required int positionMs,
    double? playbackRate,
  }) async {
    final state = _state;

    if (state == null) {
      return;
    }

    final next = state.copyWith(
      isPlaying: isPlaying,
      positionMs: positionMs,
      playbackRate: playbackRate ?? state.playbackRate,
    );

    if (next == state) {
      return;
    }

    _state = next;
    await _push(reason: MediaActivityUpdateReason.playbackChanged);
  }

  /// A seek landed; the lock-screen clock re-baselines (spec §8.7).
  Future<void> onSeekCompleted({required int positionMs}) async {
    final state = _state;

    if (state == null || state.positionMs == positionMs) {
      return;
    }

    _state = state.copyWith(positionMs: positionMs);
    await _push(reason: MediaActivityUpdateReason.seekCompleted);
  }

  /// New artwork landed under [artworkKey]. Merged: the artwork is a static
  /// attribute (spec §7.2), so the change rides along until the next natural
  /// recreate (flushMerged / track change) instead of spending its own
  /// recreate now; Now Playing reflects it immediately.
  Future<void> onArtworkChanged(String artworkKey) async {
    final metadata = _metadata;

    if (metadata == null || metadata.artworkKey == artworkKey) {
      return;
    }

    _metadata = _copyMetadata(metadata, artworkKey: artworkKey);
    _mergedPending = true;
    await _syncNowPlaying();
  }

  /// Track text changed without a session change. Merged like artwork: the
  /// activity's static attributes refresh on the next recreate, Now Playing
  /// immediately. A no-op when nothing actually changed — a replayed event
  /// must not spend budget (spec §8.1).
  Future<void> onMetadataChanged({
    String? title,
    String? artist,
    String? album,
  }) async {
    final metadata = _metadata;

    if (metadata == null) {
      return;
    }

    final next = _copyMetadata(metadata, title: title, artist: artist, album: album);

    if (next == metadata) {
      return;
    }

    _metadata = next;
    _mergedPending = true;
    await _syncNowPlaying();
  }

  /// The viewer stopped the session: end the activity and clear Now Playing
  /// (stop semantics, spec §9.4).
  Future<void> onSessionEnded() async {
    _metadata = null;
    _state = null;
    _mergedPending = false;

    await _controller.end(clearNowPlaying: true);
  }

  /// Recreates the activity when artwork/metadata changed while active:
  /// static attributes can only refresh by ending and starting again (spec
  /// §7.2). A no-op when nothing is pending or the activity is already gone.
  Future<void> flushMerged() async {
    final metadata = _metadata;
    final state = _state;

    if (!_mergedPending || metadata == null || state == null) {
      return;
    }

    _mergedPending = false;

    // Now Playing keeps playing through the recreate; the system media card
    // is refreshed right after with the new identity.
    await _controller.end();
    await _controller.start(metadata: metadata, state: state);
    await _syncNowPlaying();
  }

  Future<void> _push({required MediaActivityUpdateReason reason}) async {
    final state = _state;
    final metadata = _metadata;

    if (state == null || metadata == null) {
      return;
    }

    switch (policy.decide(reason, activityActive: true)) {
      case MediaActivitySyncDecision.immediate:
      case MediaActivitySyncDecision.merged:
        await _controller.update(state);

      case MediaActivitySyncDecision.skip:
        break;
    }
  }

  /// Mirrors the session onto the system media card. Non-live by default:
  /// a live-stream host owns its Now Playing payload directly through
  /// [MediaActivityController.updateNowPlaying] instead.
  Future<void> _syncNowPlaying() async {
    final metadata = _metadata;
    final state = _state;

    if (metadata == null || state == null) {
      return;
    }

    await _controller.updateNowPlaying(NowPlayingUpdate(
      title: metadata.title,
      artist: metadata.artist,
      album: metadata.album,
      artworkKey: metadata.artworkKey,
      positionMs: state.positionMs,
      playbackRate: state.playbackRate,
    ));
  }

  MediaActivityMetadata _copyMetadata(
    MediaActivityMetadata metadata, {
    String? title,
    String? artist,
    String? album,
    String? artworkKey,
  }) {
    return MediaActivityMetadata(
      sessionId: metadata.sessionId,
      title: title ?? metadata.title,
      artist: artist ?? metadata.artist,
      album: album ?? metadata.album,
      artworkKey: artworkKey ?? metadata.artworkKey,
    );
  }
}
