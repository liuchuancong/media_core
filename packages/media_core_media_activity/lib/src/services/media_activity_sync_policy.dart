/// Why the coordinator is about to touch the activity (spec §8.3).
enum MediaActivityUpdateReason {
  /// A different track/session took over playback.
  trackChanged,

  /// The lyric boundary advanced to another line — an event, never a tick.
  lyricChanged,

  /// Play/pause/rate changed (not ordinary position progress).
  playbackChanged,

  /// The viewer seeked; the timeline re-baselines (spec §8.7).
  seekCompleted,

  /// New artwork landed in the App Group container under a new key.
  artworkChanged,

  /// Title/artist/album text changed without a track change.
  metadataChanged,

  /// A recovery path re-claims the activity (app resume, plugin rebind).
  recovery,
}

/// What the policy tells the coordinator to do about one reason (spec §8.4).
enum MediaActivitySyncDecision {
  /// Push to the native side right away.
  immediate,

  /// Hold the change locally; it rides along with the next push. Artwork
  /// and metadata changes fold in this way so a burst of them costs one
  /// channel round trip instead of several.
  merged,

  /// Drop it. Ordinary playback progress never reaches ActivityKit: the
  /// lock screen advances its own clock between updates (spec §8.1).
  skip,
}

/// The update policy of the feature (spec §8.4), as a pure object.
///
/// No timers, no channels, no state — the coordinator hands it a reason and
/// gets a decision, which keeps the whole cadence question testable in
/// isolation from the platform.
final class MediaActivitySyncPolicy {
  /// Creates the policy; the default is the spec's priority table.
  const MediaActivitySyncPolicy();

  /// Decides what to do with [reason].
  ///
  /// [activityActive] gates everything: while no activity exists the only
  /// meaningful reason is one that will start it (the coordinator handles
  /// that), so the policy skips the rest rather than issuing phantom
  /// updates the native manager would refuse.
  MediaActivitySyncDecision decide(
    MediaActivityUpdateReason reason, {
    required bool activityActive,
  }) {
    if (!activityActive) {
      return MediaActivitySyncDecision.skip;
    }

    return switch (reason) {
      // Terminal and viewer-visible events sync at once (spec §8.4).
      MediaActivityUpdateReason.trackChanged ||
      MediaActivityUpdateReason.lyricChanged ||
      MediaActivityUpdateReason.playbackChanged ||
      MediaActivityUpdateReason.seekCompleted ||
      MediaActivityUpdateReason.recovery =>
        MediaActivitySyncDecision.immediate,

      // Cosmetic changes ride along with the next push.
      MediaActivityUpdateReason.artworkChanged ||
      MediaActivityUpdateReason.metadataChanged =>
        MediaActivitySyncDecision.merged,
    };
  }
}
