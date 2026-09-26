/// System media surfaces for `media_core`.
///
/// One capability, four platforms: a media notification with controls on
/// Android, the lock screen and Control Center on iOS, SMTC on Windows and
/// MPRIS on Linux — plus audio focus, interruptions and pause-on-unplug. It
/// works for **any** player the kernel owns, video included; that is the reason
/// it is a package of its own rather than part of the music module.
///
/// ```dart
/// final kernel = PlayerKernel();
///
/// final session = MediaSessionDriver(config: const MediaSessionConfig.video());
/// await session.initialize();          // once, early
/// kernel.attachAudio(session);         // the kernel hands over active players
///
/// // Tell the surfaces where artwork comes from, for a source that has none:
/// session.artUriResolver = (source) => thumbnailFor(source.uri);
///
/// final handle = await kernel.create(source: source, config: const PlayerConfig(autoPlay: true));
/// // The notification now shows the title, play/pause, ±10s and stop, and the
/// // buttons drive this handle.
/// ```
///
/// What the host still owns (a library cannot declare these for the app):
///
/// - Android: `AudioServiceActivity`, the `AudioService` service and
///   `MediaButtonReceiver` entries in the manifest, plus the
///   `POST_NOTIFICATIONS` permission on API 33+ (`media_core_audio`'s
///   `AudioPermissionService` asks for exactly that one, or use your own
///   permission plugin);
/// - iOS: the `audio` background mode in `Info.plist`, otherwise the lock
///   screen entry disappears when the app is suspended;
/// - drawables for the control icons named in [MediaSessionConfig].
library;

export 'src/media_session_config.dart';
export 'src/media_session_driver.dart';
export 'src/media_session_handler.dart';
