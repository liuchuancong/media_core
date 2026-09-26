/// Music playback for media_core: sources, queue, lyrics, desktop lyrics,
/// background playback and downloads — logic only, no UI and no theme.
///
/// The package has two halves that can be used independently:
///
/// **1. Capability (host-facing)** — bridges the kernel to the platform:
///
/// - `audio_service` — media notification, lock screen controls, background
///   playback (Android/iOS; Windows via audio_service_win)
/// - `audio_session` — audio focus, interruptions (calls, other apps),
///   becoming-noisy (headphones unplugged)
///
/// ```dart
/// final audio = MediaCoreAudio();
/// await audio.initialize();
/// kernel.attachAudio(audio);
/// ```
///
/// **2. Music (player-facing)** — a player built for songs:
///
/// ```dart
/// final kernel = PlayerKernel()..registerBackend(MediaKitPlayerAdapter.defaultRegistration());
/// final registry = MusicSourceRegistry([myPlatformSource, LocalMusicSource(roots: ['/music'])]);
/// final player = AudioPlaybackController(kernel, registry: registry);
///
/// // Queue + play modes (list / list-loop / single-loop / random)
/// await player.setQueue(await myPlatformSource.search('周杰伦'));
/// player.setPlayMode(PlayMode.random);
///
/// // Lyrics (LRC with translation and word timing), cached and prefetching
/// final lyric = await player.loadCurrentLyric();
///
/// // Desktop lyrics: this package owns the logic, the host owns the window
/// final overlay = DesktopLyricController(player);
/// await overlay.show();
///
/// // Background playback: notification/lock-screen/MPRIS with real metadata
/// final background = MusicBackgroundBinding(player, audio)..attach();
///
/// // Downloads (ffmpeg: HLS, signed CDNs, tags, codec choice)
/// final downloads = MusicDownloadQueue();
/// downloads.downloadTrack(track: track, source: source, directory: '/music');
/// ```
library;

// Capability (background audio + audio session).
export 'src/audio_capability_config.dart';
export 'src/media_core_audio.dart';
export 'src/media_core_audio_handler.dart';

// Background playback binding for the music player.
export 'src/background/music_background_binding.dart';

// Desktop lyrics (logic + host transport; the window is the host's).
export 'src/desktop_lyric/desktop_lyric_controller.dart';
export 'src/desktop_lyric/desktop_lyric_state.dart';
export 'src/desktop_lyric/desktop_lyric_transport.dart';

// Downloads.
export 'src/download/music_download_queue.dart';
export 'src/download/music_download_request.dart';
export 'src/download/music_download_task.dart';
export 'src/download/music_downloader.dart';

// Lyrics.
export 'src/lyric/lyric_document.dart';
export 'src/lyric/lyric_line.dart';
export 'src/lyric/lyric_loader.dart';
export 'src/lyric/lyric_timeline.dart';
export 'src/lyric/lrc_parser.dart';

// Music player.
export 'src/player/audio_playback_controller.dart';
export 'src/player/audio_player_state.dart';

// Queue and play modes.
export 'src/queue/play_mode.dart';
export 'src/queue/play_queue.dart';

// Sources.
export 'src/source/local_music_source.dart';
export 'src/source/music_source.dart';
export 'src/source/music_source_registry.dart';

// Track models.
export 'src/track/music_quality.dart';
export 'src/track/music_track.dart';
export 'src/track/track_source.dart';
