import '../pages/feed_demo_page.dart';
import '../pages/live_demo_page.dart';
import '../pages/music_demo_page.dart';
import '../pages/player_demo_page.dart';
import '../pages/presentation_demo_page.dart';
import 'console/lyric_demo.dart';
import 'console/platform_demo.dart';
import 'console/queue_demo.dart';
import 'console/source_demo.dart';
import 'module_demo.dart';
import 'runnable_demo.dart';

/// Pages that play media.
///
/// These are the demos a developer debugs against: each one creates a real
/// player, so the framework's behaviour (backend selection, recovery,
/// watchdogs, lyrics timing) is observable instead of described.
final List<RunnableDemo> runnableDemos = <RunnableDemo>[
  RunnableDemo(
    id: 'player',
    nameZh: '播放器与生命周期',
    nameEn: 'Player & lifecycle',
    purposeZh: 'kernel → 注册后端 → create → open → play；含 seek / 音量 / 倍速 / 静音 / 循环与操作记录。',
    purposeEn: 'kernel → register backend → create → open → play; with seek, volume, rate, mute, loop and operation records.',
    builder: (_) => const PlayerDemoPage(),
  ),
  RunnableDemo(
    id: 'live',
    nameZh: '直播多线路与引擎回退',
    nameEn: 'Live lines & engine fallback',
    purposeZh: '多线路请求：同引擎换线 → 换引擎重扫 → 都失败才 onError，一次。',
    purposeEn: 'Multi-line request: lines on one engine → next engine → a single onError when everything is spent.',
    builder: (_) => const LiveDemoPage(),
  ),
  RunnableDemo(
    id: 'feed',
    nameZh: '短视频上下滑',
    nameEn: 'Vertical feed',
    purposeZh: '共用一个播放器换源，只有当前页挂载视频控件，下一条自动预热。',
    purposeEn: 'One shared player re-opened per item; only the visible page mounts a video widget; the next item is preloaded.',
    builder: (_) => const FeedDemoPage(),
  ),
  RunnableDemo(
    id: 'music',
    nameZh: '音乐：队列 / 歌词 / 桌面歌词 / 后台 / 下载',
    nameEn: 'Music: queue, lyrics, overlay, background, download',
    purposeZh: 'media_core_audio 的全部面：音源解析、四种播放模式、歌词时间轴、桌面歌词窗口、后台播放绑定、ffmpeg 下载。',
    purposeEn: 'The whole media_core_audio surface: source resolution, four play modes, lyric timeline, desktop lyric window, background binding, ffmpeg downloads.',
    builder: (_) => const MusicDemoPage(),
  ),
  RunnableDemo(
    id: 'presentation',
    nameZh: '全屏 / 画中画 / 悬浮窗 / 弹幕',
    nameEn: 'Fullscreen, PiP, floating & danmaku',
    purposeZh: 'kernel.attachPresentation 转发展示请求；弹幕会话由假 transport 喂消息。',
    purposeEn: 'kernel.attachPresentation forwards presentation requests; the danmaku session is fed by a synthetic transport.',
    builder: (_) => const PresentationDemoPage(),
  ),
];

/// Pure-logic modules, demonstrated by running them.
///
/// A printed result is the right medium for these: no device, no network, and
/// the output *is* the evidence — a lyric table, a queue walk, the exact ffmpeg
/// argument list.
final List<ModuleDemo> moduleDemos = <ModuleDemo>[
  const LyricDemo(),
  const QueueDemo(),
  const SourceDemo(),
  const PlatformDemo(),
];

/// Everything the catalog shows: runnable pages first, module tour second.
final Map<ModuleCategory, List<ModuleDemo>> moduleDemosByCategory = <ModuleCategory, List<ModuleDemo>>{
  for (final category in ModuleCategory.values)
    category: moduleDemos.where((demo) => demo.category == category).toList(growable: false),
};

/// Whether a category has any demo.
bool hasModuleDemos(ModuleCategory category) => (moduleDemosByCategory[category] ?? const <ModuleDemo>[]).isNotEmpty;
