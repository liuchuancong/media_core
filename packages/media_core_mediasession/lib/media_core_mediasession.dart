/// System media surfaces for `media_core`.
///
/// One capability over flutter_media_session: a media notification with
/// controls on Android, the lock screen and Control Center on iOS and macOS,
/// SMTC on Windows and the Media Session API on the web — plus audio focus
/// interruptions. It
/// works for **any** player the kernel owns, video included; that is the reason
/// it is a package of its own rather than part of the music module.
///
/// The one thing a host has to do is say yes, once, at app start — after that
/// every player is published automatically:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await MediaSessionBootstrap.enable();   // every kernel takes it from here
///   runApp(const MyApp());
/// }
/// ```
///
/// Or drive it explicitly, per kernel:
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
/// - iOS: the `audio` background mode in `Info.plist`, otherwise the lock
///   screen entry disappears when the app is suspended;
/// - Windows (unpackaged): an AppUserModelID, so SMTC names the app.
///
/// The Android service, its permissions and the API 33+ notification prompt
/// come with flutter_media_session. Linux has no surface yet: enabling there
/// throws [UnsupportedError].
library;


export 'package:media_core_mediasession/src/media_session_bootstrap.dart';
export 'package:media_core_mediasession/src/media_session_config.dart';
export 'package:media_core_mediasession/src/media_session_driver.dart';
export 'package:media_core_mediasession/src/media_session_handler.dart';
export 'package:media_core_mediasession/src/media_session_models.dart';
export 'package:media_core_mediasession/src/media_session_surfaces.dart';
