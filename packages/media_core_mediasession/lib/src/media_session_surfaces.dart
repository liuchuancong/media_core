import 'package:media_core/media_core.dart' show MediaSessionActivation, MediaSessionRefusal;
import 'package:media_core_mediasession/src/media_session_bootstrap.dart';
import 'package:media_core_mediasession/src/media_session_driver.dart';

/// The metadata key a source's cover travels under: the room art that the
/// media surfaces should show, a URL string.
const String mediaSessionArtUriKey = 'artUri';

/// The media surfaces, reached by name instead of by a player handle.
///
/// The kernel binds the active player and that covers the ordinary case: whoever
/// is playing owns the notification, the lock screen, SMTC or MPRIS. This door is
/// for the other case — a host with no `PlayerHandle` to bind (its own player, a
/// live wall that wants a named cell to hold the bar, a session that must be
/// handed over before the next one starts) — and for the one thing a handle cannot
/// express: *which session* is claiming the surface, so a late callback from the
/// previous owner can be recognised as stale and dropped.
///
/// ```dart
/// await MediaSessionBootstrap.enable();            // once, at startup
///
/// final activation = await MediaSessionSurfaces.activate(
///   sessionId: 'wall/cell-2',
///   title: '房间 42',
/// );
/// if (!activation.held) {
///   // The platform has no surface here, or the handshake has not finished.
///   // Saying so is the point: a control bar nobody claimed is worse than one
///   // that reports it is showing something it is not.
/// }
///
/// await MediaSessionSurfaces.updateMetadata(sessionId: 'wall/cell-2', title: '房间 42 · 00:12');
/// await MediaSessionSurfaces.deactivate('wall/cell-2');
/// ```
///
/// Nothing here starts a service or posts a notification of its own; the media
/// surface belongs to `audio_service` on Android (declared by the host's manifest)
/// and to SMTC/MPRIS on desktop. Job notifications — recording, download — are a
/// different owner entirely: `media_core_native`'s per-feature services.
abstract final class MediaSessionSurfaces {
  /// Which session holds the surface right now, or null when nobody does.
  ///
  /// Null means either "no owner" or "no surfaces in this process", and the two are
  /// told apart by [activate]'s refusal reason, not by guessing from a null.
  static String? get activeSessionId => MediaSessionBootstrap.current?.activeSessionId;

  /// Takes the surface for [sessionId], showing [title].
  ///
  /// Refused with `MediaSessionRefusal.notEnabled` when this process never enabled
  /// the surfaces — the case `MediaSessionBootstrap.current == null` leaves the host
  /// to notice for themselves, which is how a silent `null` becomes a reported
  /// "playing in the background" that the device never provided.
  ///
  /// The previous holder, if any, is named in the result: whoever lost the bar
  /// usually cannot see it from their own side.
  static Future<MediaSessionActivation> activate({required String sessionId, required String title}) {
    final driver = MediaSessionBootstrap.current;

    if (driver == null) {
      return Future<MediaSessionActivation>.value(
        const MediaSessionActivation.refused(MediaSessionRefusal.notEnabled),
      );
    }

    return driver.activate(sessionId: sessionId, title: title);
  }

  /// Replaces the title the surface shows, if [sessionId] still holds it.
  ///
  /// A call from a session that no longer owns the surface is ignored — that is the
  /// guard, not an accident: the multiview switch whose old cell rewrote the new
  /// cell's control bar is the bug this exists to make impossible. With no surfaces
  /// enabled there is nothing to rewrite, so this is a no-op rather than an error.
  static Future<void> updateMetadata({required String sessionId, required String title}) async {
    await MediaSessionBootstrap.current?.updateMetadata(sessionId: sessionId, title: title);
  }

  /// Gives up the surface, if [sessionId] is the one holding it.
  ///
  /// Releasing is how the platform's "now playing" entry and, on Android, the media
  /// foreground service go away; a session that never claims it back leaves the bar
  /// describing a player that no longer exists.
  static Future<void> deactivate(String sessionId) async {
    await MediaSessionBootstrap.current?.deactivate(sessionId);
  }

  /// The driver behind these calls, for a host that needs more than the named
  /// session: binding a handle ([MediaSessionDriver.setActive]), reading the
  /// handler, or configuring it.
  static MediaSessionDriver? get driver => MediaSessionBootstrap.current;
}
