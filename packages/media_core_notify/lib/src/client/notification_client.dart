/// The seam between the notification vocabulary and whatever draws it.
///
/// One implementation ships ([FlutterLocalNotificationsClient], on top of
/// `flutter_local_notifications`). A host that already owns a notification
/// pipeline — or a test that has no platform at all — passes something else to
/// [MediaCoreNotify.enable] instead, which is why the rest of the package never
/// touches the plugin directly.
library;

import 'package:media_core/media_core.dart' show BackgroundServiceOwner;
import 'package:media_core_notify/media_core_notify.dart' show FlutterLocalNotificationsClient, MediaCoreNotify;

import 'package:media_core_notify/src/client/notify_event.dart';

/// The notification id the generic job line owns.
///
/// Fixed per feature, because a line is one notification that gets replaced as the
/// jobs under it change — not one per job. Posted events draw their own ids from
/// [kFirstPostedNotificationId], so the two never collide.
///
/// The value is the one the single job line always had, so a host upgrading keeps
/// its own unread-count history for unnamed work.
const int kRunningLineNotificationId = 1;

/// The notification id the recording line owns.
const int kRecordingLineNotificationId = 2;

/// The notification id the download line owns.
const int kDownloadLineNotificationId = 3;

/// Where ids for posted events start counting.
const int kFirstPostedNotificationId = 1000;

/// The notification id the line for [owner] owns.
///
/// One id per feature is what makes the lines independent: taking the download
/// line down when the last transfer finishes cannot blank a recording's line, and
/// two features can never overwrite one another's text.
///
/// [BackgroundServiceOwner.mediaSession] has no job line — playback is announced
/// by the media notification, which `media_core_mediasession` owns — so asking for
/// its id is a routing mistake, said as one.
int runningLineIdFor(BackgroundServiceOwner owner) => switch (owner) {
  BackgroundServiceOwner.recording => kRecordingLineNotificationId,
  BackgroundServiceOwner.download => kDownloadLineNotificationId,
  BackgroundServiceOwner.genericJob => kRunningLineNotificationId,
  BackgroundServiceOwner.mediaSession => throw ArgumentError.value(
    owner,
    'owner',
    'the media session is announced by the media notification, not by a job line',
  ),
};

/// How a client should be set up.
final class NotifySetup {
  /// Creates a setup description.
  const NotifySetup({
    this.channels = const <NotifyChannel>[
      kNotifyChannelRecording,
      kNotifyChannelDownload,
      kNotifyChannelJobs,
      kNotifyChannelResults,
    ],
    this.androidSmallIcon = '@mipmap/ic_launcher',
    this.onTap,
  });

  /// Channels to register. A platform without channels (Windows, Linux, iOS)
  /// treats this as grouping metadata only.
  final List<NotifyChannel> channels;

  /// The drawable the Android status-bar icon comes from, in the plugin's own
  /// notation (`@drawable/ic_stat_media_core_record` or `@mipmap/ic_launcher`).
  final String androidSmallIcon;

  /// Called when one of this app's notifications is opened.
  final void Function(NotifyTap tap)? onTap;

  /// The channel [owner]'s line is drawn on.
  ///
  /// Falls back to the catch-all jobs channel when a host trimmed the feature's
  /// own channel out of [channels]: a line posted to a channel nobody registered is
  /// a line the user cannot silence, which is worse than it sharing the one channel
  /// that does exist.
  NotifyChannel channelFor(BackgroundServiceOwner owner) {
    final wanted = switch (owner) {
      BackgroundServiceOwner.recording => kNotifyChannelRecording,
      BackgroundServiceOwner.download => kNotifyChannelDownload,
      BackgroundServiceOwner.genericJob || BackgroundServiceOwner.mediaSession => kNotifyChannelJobs,
    };

    return channels.firstWhere((channel) => channel.id == wanted.id, orElse: () => kNotifyChannelJobs);
  }

  @override
  String toString() =>
      'NotifySetup(channels: ${channels.map((channel) => channel.id).toList()}, icon: $androidSmallIcon)';
}

/// What any notification backend has to be able to do.
///
/// Every method is fire-and-forget on purpose: a notification is never a reason
/// for a job to fail, so the facade swallows what these throw. A client that
/// cannot reach a platform should return normally, not throw — the caller has no
/// useful thing to do with the difference.
abstract interface class LocalNotificationClient {
  /// Registers channels and returns whether notifications can be shown at all.
  Future<bool> configure(NotifySetup setup);

  /// Asks the platform for permission to show notifications.
  ///
  /// `true` when granted. On a platform with no such question (Linux, Windows)
  /// it reports whether the mechanism is there at all.
  Future<bool> requestPermission();

  /// Whether the user currently lets notifications through, without asking.
  Future<bool> notificationsEnabled();

  /// Shows one event, replacing any earlier event with the same [NotifyEvent.id].
  Future<void> post(NotifyEvent event);

  /// Removes the notification with [id], if one is showing.
  Future<void> dismiss(int id);

  /// Shows one feature's running line, replacing the line with the same
  /// [NotifyEvent.id].
  ///
  /// This is a notification and nothing else: the line is non-dismissible while
  /// that feature's jobs run, and it carries the count of what else of *its own*
  /// kind is working, but the service behind the work is `media_core_native`'s and
  /// its notification is drawn there. A client that draws the line on Android too
  /// would give one job two persistent notifications, which is the duplication this
  /// call used to be a foreground service for.
  ///
  /// The id is the line's identity: one per feature, so a recording's line and a
  /// download's line are two notifications that cannot overwrite each other.
  Future<void> showRunningLine(NotifyEvent event);

  /// Takes the running line with [id] away, with no jobs of that feature left.
  Future<void> clearRunningLine({required int id});
}
