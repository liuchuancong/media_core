import 'package:media_core_media_activity/media_core_media_activity.dart';

/// A recording [MediaActivityPlatform] for controller/coordinator tests.
///
/// Every call appends a short entry to [log] in exact call order, so tests
/// assert sequences ('end before start') rather than just presence.
class FakeMediaActivityPlatform implements MediaActivityPlatform {
  /// Creates the fake with the capability report it should answer with.
  FakeMediaActivityPlatform({
    this.report = usableReport,
    this.status = const MediaActivityStatus(isActive: true, isDismissed: false),
  });

  /// A fully green report — the default; tests flip fields to degrade.
  static const usableReport = MediaActivityCapabilitiesReport(
    isSupported: true,
    activitiesEnabled: true,
    frequentUpdatesEnabled: true,
    supportsDynamicIsland: true,
    systemMajorVersion: 18,
  );

  /// What [capabilities] answers.
  MediaActivityCapabilitiesReport report;

  /// What [activityStatus] answers.
  MediaActivityStatus status;

  /// What [startActivity] / [updateActivity] / [endActivity] return; flip to
  /// a [MediaActivityCallResult.failed] to exercise the refusal paths.
  MediaActivityCallResult startResult = const MediaActivityCallResult.ok();
  MediaActivityCallResult updateResult = const MediaActivityCallResult.ok();
  MediaActivityCallResult endResult = const MediaActivityCallResult.ok();

  /// Call-order trace: `capabilities`, `start:<sessionId>`, `update:<sessionId>`,
  /// `end:<sessionId>`, `endAll`, `nowPlaying`, `clearNowPlaying`,
  /// `configureCommands`.
  final List<String> log = [];

  final List<MediaActivityMetadata> startedMetadata = [];
  final List<MediaActivityContentState> startedStates = [];
  final List<MediaActivityContentState> updatedStates = [];
  final List<NowPlayingUpdate> nowPlayingUpdates = [];
  MediaActivityCommandSink? sink;

  @override
  Future<MediaActivityCapabilitiesReport> capabilities() async {
    log.add('capabilities');

    return report;
  }

  @override
  Future<MediaActivityCallResult> startActivity({
    required MediaActivityMetadata metadata,
    required MediaActivityContentState initialState,
  }) async {
    log.add('start:${metadata.sessionId}');
    startedMetadata.add(metadata);
    startedStates.add(initialState);

    return startResult;
  }

  @override
  Future<MediaActivityCallResult> updateActivity({
    required String sessionId,
    required MediaActivityContentState state,
  }) async {
    log.add('update:$sessionId');
    updatedStates.add(state);

    return updateResult;
  }

  @override
  Future<MediaActivityCallResult> endActivity({required String sessionId}) async {
    log.add('end:$sessionId');

    return endResult;
  }

  @override
  Future<void> endAllActivities() async {
    log.add('endAll');
  }

  @override
  Future<MediaActivityStatus> activityStatus({required String sessionId}) async {
    log.add('status:$sessionId');

    return status;
  }

  @override
  Future<void> updateNowPlaying(NowPlayingUpdate update) async {
    log.add('nowPlaying');
    nowPlayingUpdates.add(update);
  }

  @override
  Future<void> clearNowPlaying() async {
    log.add('clearNowPlaying');
  }

  @override
  Future<void> configureRemoteCommands({
    required bool playPauseEnabled,
    required bool nextTrackEnabled,
    required bool previousTrackEnabled,
    required bool seekEnabled,
  }) async {
    log.add('configureCommands');
  }

  @override
  void setCommandSink(MediaActivityCommandSink? sink) {
    this.sink = sink;
  }
}

/// A recording [MediaActivityCommandSink] for command-routing tests.
class RecordingCommandSink implements MediaActivityCommandSink {
  /// Commands received, in arrival order.
  final List<String> log = [];

  @override
  void onActivityDismissed(String sessionId) => log.add('dismissed:$sessionId');

  @override
  void onPlay(String playerId) => log.add('play:$playerId');

  @override
  void onPause(String playerId) => log.add('pause:$playerId');

  @override
  void onTogglePlayPause(String playerId) => log.add('toggle:$playerId');

  @override
  void onNextTrack(String playerId) => log.add('next:$playerId');

  @override
  void onPreviousTrack(String playerId) => log.add('previous:$playerId');

  @override
  void onSeek(String playerId, int positionMs) => log.add('seek:$playerId@$positionMs');
}
