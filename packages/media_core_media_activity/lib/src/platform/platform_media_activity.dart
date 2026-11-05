import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:media_core_media_activity/src/interfaces/media_activity_platform.dart';
import 'package:media_core_media_activity/src/models/media_activity_capabilities.dart';
import 'package:media_core_media_activity/src/models/media_activity_metadata.dart';
import 'package:media_core_media_activity/src/models/media_activity_state.dart';
import 'package:media_core_media_activity/src/platform/method_channel_media_activity.dart';

/// The no-op platform: everything degrades, nothing throws (spec §13.3).
///
/// This is what every non-iOS platform (and an iOS build whose plugin never
/// registered) resolves to; the feature reads as "off" and playback is
/// untouched.
final class NoopMediaActivityPlatform implements MediaActivityPlatform {
  /// One instance serves every host — the class holds no state.
  const NoopMediaActivityPlatform();

  @override
  Future<MediaActivityCapabilitiesReport> capabilities() async =>
      MediaActivityCapabilitiesReport.unsupported;

  @override
  Future<MediaActivityCallResult> startActivity({
    required MediaActivityMetadata metadata,
    required MediaActivityContentState initialState,
  }) async =>
      const MediaActivityCallResult.failed('activity_not_supported');

  @override
  Future<MediaActivityCallResult> updateActivity({
    required String sessionId,
    required MediaActivityContentState state,
  }) async =>
      const MediaActivityCallResult.failed('activity_not_supported');

  @override
  Future<MediaActivityCallResult> endActivity({required String sessionId}) async =>
      const MediaActivityCallResult.failed('activity_not_supported');

  @override
  Future<void> endAllActivities() async {}

  @override
  Future<MediaActivityStatus> activityStatus({required String sessionId}) async =>
      const MediaActivityStatus(isActive: false, isDismissed: false);

  @override
  Future<void> updateNowPlaying(NowPlayingUpdate update) async {}

  @override
  Future<void> clearNowPlaying() async {}

  @override
  Future<void> configureRemoteCommands({
    required bool playPauseEnabled,
    required bool nextTrackEnabled,
    required bool previousTrackEnabled,
    required bool seekEnabled,
  }) async {}

  @override
  void setCommandSink(MediaActivityCommandSink? sink) {}
}

/// Picks the platform implementation for the current runtime.
///
/// Only iOS gets the bridge; everything else shares the no-op. The choice is
/// made once — a host holds one platform for the app's lifetime.
final class PlatformMediaActivity {
  PlatformMediaActivity._();

  /// The platform implementation for the current runtime.
  static MediaActivityPlatform resolve() {
    if (kIsWeb) {
      return const NoopMediaActivityPlatform();
    }

    try {
      if (Platform.isIOS) {
        return MethodChannelMediaActivity();
      }
    } on Object {
      // A missing platform override (tests, embedded hosts) is the no-op
      // case, not an error.
    }

    return const NoopMediaActivityPlatform();
  }
}
