import 'package:flutter/services.dart';
import 'package:media_core_media_activity/src/interfaces/media_activity_platform.dart';
import 'package:media_core_media_activity/src/models/media_activity_capabilities.dart';
import 'package:media_core_media_activity/src/models/media_activity_metadata.dart';
import 'package:media_core_media_activity/src/models/media_activity_state.dart';
import 'package:media_core_media_activity/src/platform/media_activity_api.g.dart' as generated;

/// [MediaActivityPlatform] backed by the Pigeon bridge to the iOS plugin.
///
/// The mapping is deliberately total: every generated field is set from a
/// hand-written model (and vice versa), so adding a field to one side
/// without the other is a compile error here rather than a lost field on
/// the lock screen.
///
/// This class is also the receiving end of the command protocol: it
/// implements the generated [generated.MediaActivityCommandApi] so iOS can
/// deliver remote commands and dismissal events, which it forwards to the
/// registered [MediaActivityCommandSink].
final class MethodChannelMediaActivity
    implements MediaActivityPlatform, generated.MediaActivityCommandApi {
  /// Creates the bridge over the default binary messenger.
  MethodChannelMediaActivity() {
    generated.MediaActivityCommandApi.setUp(this, binaryMessenger: _messenger);
  }

  final BinaryMessenger _messenger = ServicesBinding.instance.defaultBinaryMessenger;

  final generated.MediaActivityApi _api = generated.MediaActivityApi();

  MediaActivityCommandSink? _sink;

  @override
  Future<MediaActivityCapabilitiesReport> capabilities() async {
    final report = await _api.getCapabilities();

    return MediaActivityCapabilitiesReport(
      isSupported: report.isSupported,
      activitiesEnabled: report.activitiesEnabled,
      frequentUpdatesEnabled: report.frequentUpdatesEnabled,
      supportsDynamicIsland: report.supportsDynamicIsland,
      systemMajorVersion: report.systemMajorVersion,
    );
  }

  @override
  Future<MediaActivityCallResult> startActivity({
    required MediaActivityMetadata metadata,
    required MediaActivityContentState initialState,
  }) async {
    final result = await _api.startActivity(
      _toGeneratedMetadata(metadata),
      _toGeneratedState(initialState),
    );

    return _toResult(result);
  }

  @override
  Future<MediaActivityCallResult> updateActivity({
    required String sessionId,
    required MediaActivityContentState state,
  }) async {
    final result = await _api.updateActivity(sessionId, _toGeneratedState(state));

    return _toResult(result);
  }

  @override
  Future<MediaActivityCallResult> endActivity({required String sessionId}) async {
    final result = await _api.endActivity(sessionId);

    return _toResult(result);
  }

  @override
  Future<void> endAllActivities() => _api.endAllActivities();

  @override
  Future<MediaActivityStatus> activityStatus({required String sessionId}) async {
    final report = await _api.getActivityState(sessionId);

    return MediaActivityStatus(isActive: report.isActive, isDismissed: report.isDismissed);
  }

  @override
  Future<void> updateNowPlaying(NowPlayingUpdate update) => _api.updateNowPlaying(
        generated.NowPlayingMetadata(
          title: update.title,
          artist: update.artist,
          album: update.album,
          artworkKey: update.artworkKey,
          durationMs: update.durationMs,
          positionMs: update.positionMs,
          playbackRate: update.playbackRate,
          isLive: update.isLive,
        ),
      );

  @override
  Future<void> clearNowPlaying() => _api.clearNowPlaying();

  @override
  Future<void> configureRemoteCommands({
    required bool playPauseEnabled,
    required bool nextTrackEnabled,
    required bool previousTrackEnabled,
    required bool seekEnabled,
  }) =>
      _api.configureRemoteCommands(
        generated.RemoteCommandConfig(
          playPauseEnabled: playPauseEnabled,
          nextTrackEnabled: nextTrackEnabled,
          previousTrackEnabled: previousTrackEnabled,
          seekEnabled: seekEnabled,
        ),
      );

  @override
  void setCommandSink(MediaActivityCommandSink? sink) {
    _sink = sink;
  }

  // -- Pigeon FlutterApi callbacks (iOS -> Dart) ------------------------------

  @override
  void onPlay(String playerId) => _sink?.onPlay(playerId);

  @override
  void onPause(String playerId) => _sink?.onPause(playerId);

  @override
  void onTogglePlayPause(String playerId) => _sink?.onTogglePlayPause(playerId);

  @override
  void onNextTrack(String playerId) => _sink?.onNextTrack(playerId);

  @override
  void onPreviousTrack(String playerId) => _sink?.onPreviousTrack(playerId);

  @override
  void onSeek(String playerId, int positionMs) => _sink?.onSeek(playerId, positionMs);

  @override
  void onActivityDismissed(String sessionId) => _sink?.onActivityDismissed(sessionId);

  // -- Mapping ---------------------------------------------------------------

  generated.MediaActivityMetadata _toGeneratedMetadata(MediaActivityMetadata metadata) {
    return generated.MediaActivityMetadata(
      sessionId: metadata.sessionId,
      title: metadata.title,
      artist: metadata.artist,
      album: metadata.album,
      artworkKey: metadata.artworkKey,
    );
  }

  generated.MediaActivityContentState _toGeneratedState(MediaActivityContentState state) {
    return generated.MediaActivityContentState(
      currentLyric: state.currentLyric,
      nextLyric: state.nextLyric,
      isPlaying: state.isPlaying,
      positionMs: state.positionMs,
      playbackRate: state.playbackRate,
      lyricRevision: state.lyricRevision,
    );
  }

  MediaActivityCallResult _toResult(generated.MediaActivityCallResult result) {
    if (result.ok) {
      return const MediaActivityCallResult.ok();
    }

    return MediaActivityCallResult.failed(result.errorCode ?? 'native_bridge_unavailable');
  }
}
