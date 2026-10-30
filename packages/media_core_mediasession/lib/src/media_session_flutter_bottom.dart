import 'dart:async' show StreamSubscription, unawaited;

import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:flutter_media_session/flutter_media_session.dart' as fms;

/// The Windows bottom for audio_service, over flutter_media_session.
///
/// audio_service ships no Windows surface of its own; the third-party
/// audio_service_win that used to sit here is retired. This bridge keeps the
/// driver untouched — it implements audio_service's platform interface and
/// renders onto flutter_media_session's SMTC instead: `configure` activates
/// the session, `setMediaItem` publishes the card, `setState` publishes the
/// playback state, and the OS's button presses arrive on
/// `onMediaAction` and are dispatched to the handler callbacks.
final class MediaSessionFlutterBottom extends AudioServicePlatform {
  /// Creates the bridge.
  MediaSessionFlutterBottom();

  AudioHandlerCallbacks? _handlerCallbacks;

  // Lives for the process: a platform implementation outlives every handler,
  // so the action stream is never cancelled.
  // ignore: cancel_subscriptions
  StreamSubscription<fms.MediaAction>? _actionSub;

  /// Installs this bridge as the active platform.
  static void registerWith() {
    AudioServicePlatform.instance = MediaSessionFlutterBottom();
  }

  @override
  Future<void> configure(ConfigureRequest request) async {
    _actionSub ??= fms.FlutterMediaSessionPlatform.instance.onMediaAction.listen(
      _onAction,
      onError: (Object _) {},
    );
    await fms.FlutterMediaSessionPlatform.instance.activate();
  }

  @override
  Future<void> setMediaItem(SetMediaItemRequest request) async {
    final item = request.mediaItem;
    await fms.FlutterMediaSessionPlatform.instance.updateMetadata(
      fms.MediaMetadata(
        title: item.title,
        artist: item.artist,
        album: item.album,
        artworkUri: item.artUri?.toString(),
        duration: item.duration,
      ),
    );
  }

  @override
  Future<void> setState(SetStateRequest request) async {
    final state = request.state;
    final fms.PlaybackStatus status;
    if (state.processingState == AudioProcessingStateMessage.buffering ||
        state.processingState == AudioProcessingStateMessage.loading) {
      status = fms.PlaybackStatus.buffering;
    } else if (state.playing) {
      status = fms.PlaybackStatus.playing;
    } else if (state.processingState == AudioProcessingStateMessage.idle) {
      status = fms.PlaybackStatus.idle;
    } else {
      status = fms.PlaybackStatus.paused;
    }
    await fms.FlutterMediaSessionPlatform.instance.updatePlaybackState(
      fms.PlaybackState(
        status: status,
        position: state.updatePosition,
        speed: state.speed,
        bufferedPosition: state.bufferedPosition,
        repeatMode: switch (state.repeatMode) {
          AudioServiceRepeatModeMessage.one => fms.MediaRepeatMode.one,
          AudioServiceRepeatModeMessage.all => fms.MediaRepeatMode.all,
          _ => fms.MediaRepeatMode.none,
        },
        shuffleModeEnabled: state.shuffleMode != AudioServiceShuffleModeMessage.none,
      ),
    );
  }

  @override
  Future<void> setQueue(SetQueueRequest request) async {
    // The SMTC card has no queue surface; nothing to publish.
  }

  @override
  Future<void> stopService(StopServiceRequest request) async {
    await fms.FlutterMediaSessionPlatform.instance.deactivate();
  }

  @override
  void setHandlerCallbacks(AudioHandlerCallbacks callbacks) {
    _handlerCallbacks = callbacks;
  }

  void _onAction(fms.MediaAction action) {
    final callbacks = _handlerCallbacks;
    if (callbacks == null) return;
    switch (action.name) {
      case 'play':
        unawaited(callbacks.play(const PlayRequest()));
      case 'pause':
        unawaited(callbacks.pause(const PauseRequest()));
      case 'stop':
        unawaited(callbacks.stop(const StopRequest()));
      case 'skipToNext':
        unawaited(callbacks.skipToNext(const SkipToNextRequest()));
      case 'skipToPrevious':
        unawaited(callbacks.skipToPrevious(const SkipToPreviousRequest()));
      case 'fastForward':
        unawaited(callbacks.fastForward(const FastForwardRequest()));
      case 'rewind':
        unawaited(callbacks.rewind(const RewindRequest()));
      case 'seekTo':
        unawaited(callbacks.seek(SeekRequest(position: action.seekPosition ?? Duration.zero)));
    }
  }
}
