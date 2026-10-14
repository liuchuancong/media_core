/// The seam between the notification vocabulary and whatever draws it.
///
/// One implementation ships ([FlutterLocalNotificationsClient], on top of
/// `flutter_local_notifications`). A host that already owns a notification
/// pipeline — or a test that has no platform at all — passes something else to
/// [MediaCoreNotify.enable] instead, which is why the rest of the package never
/// touches the plugin directly.
library;

import 'package:media_core_notify/media_core_notify.dart' show FlutterLocalNotificationsClient, MediaCoreNotify;

import 'package:media_core_notify/src/notify_event.dart';

/// The notification id the running-jobs line owns.
///
/// Fixed, because the line is one notification that gets replaced as the jobs
/// under it change, not one per job. Posted events draw their own ids from
/// [kFirstPostedNotificationId], so the two never collide.
const int kRunningLineNotificationId = 1;

/// Where ids for posted events start counting.
const int kFirstPostedNotificationId = 1000;

/// How a client should be set up.
final class NotifySetup {
  /// Creates a setup description.
  const NotifySetup({
    this.channels = const <NotifyChannel>[kNotifyChannelJobs, kNotifyChannelResults],
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

  /// The channel a job line belongs to, when one was not named.
  NotifyChannel get jobsChannel =>
      channels.firstWhere((channel) => channel.id == kNotifyChannelJobs.id, orElse: () => kNotifyChannelJobs);

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

  /// Shows the running-jobs line, replacing the one already showing.
  ///
  /// This is a notification and nothing else: the line is non-dismissible while
  /// jobs run, and it carries the count of what is working, but the *service*
  /// behind the work is `media_core_native`'s and its own notification is drawn
  /// there. A client that draws the line on Android too would give one job two
  /// persistent notifications, which is the duplication this call used to be a
  /// foreground service for.
  Future<void> showRunningLine(NotifyEvent event);

  /// Takes the running-jobs line away, with no jobs left to show.
  Future<void> clearRunningLine();
}
