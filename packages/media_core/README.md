# media_core

Flutter 播放器的**编排内核**：一份与引擎无关的 `PlayerAdapter` 契约，加上会话、命令串行化、恢复决策、池化、事件归一化与诊断这些"每个播放器都要重做一遍"的难事。本包不含平台代码、不含 UI 主题、不内置任何解码引擎。

## 定位

播放器的通用难点不在解码，而在决策与状态：一次 `seek` 与一次恢复重开撞车时谁赢、切换引擎后旧会话迟到的事件该不该认、列表里六个播放器谁持有音频、断流之后是原地重开、换线路还是换引擎。这一层把这些做成模块，把"具体怎么解码"留给适配包。

- 依赖只有 Flutter、两个基础设施包（[media_core_logging](../media_core_logging/README.md)、[media_core_memory](../media_core_memory/README.md)）与少量纯 Dart 库（rxdart、equatable、freezed_annotation、json_annotation、collection、meta、mime、async、clock、path、pool、fuzzywuzzy）。
- 引擎来自四个后端适配包：[media_core_media_kit](../media_core_media_kit/README.md)（libmpv）、[media_core_fvp](../media_core_fvp/README.md)（libmdk）、[media_core_ijk_player](../media_core_ijk_player/README.md)（ijk / `flv_lzc`）、[media_core_better_player](../media_core_better_player/README.md)（better_player_plus）。
- 设备事实、系统媒体面、控件、投屏、录制分别由 `media_core_native` / `media_core_mediasession` / `media_core_ui` / `media_core_cast_dlna` / `media_core_recording_ffmpeg` 实现本包定义的接口。
- 一个后端都没注册时 `PlayerKernel.create` 抛 `StateError`：这一层不会悄悄退化成"内建播放器"。

## 用法

```dart
import 'package:media_core/media_core.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKitPlayerAdapter.ensureInitialized();            // 引擎侧加载

  final kernel = PlayerKernel()
    ..registerBackend(MediaKitAdapterFactory().registration());   // 默认 priority 100

  final handle = await kernel.create(
    source: PlayerSource(id: SourceId('demo'), uri: Uri.parse('https://example.com/video.mp4')),
    config: const PlayerConfig(autoPlay: true, volume: 0.6),
  );

  handle.playbackStream.listen((transport) => setState(() {}));   // ValueStream<PlayerTransportState>
  handle.recoveryEvents.listen((event) => print('recovery ${event.kind}'));

  await handle.seek(const Duration(seconds: 30));
  await handle.setRate(1.25);
  await kernel.captureScreenshot(handle.id);
  await kernel.release(handle.id);                       // 软复用则用 handle.recycle() + kernel.acquire()
}
```

门面之外都是可直接消费的流与快照：`stateChanges`、`snapshots` / `snapshot`、`adapterEvents`、`backendChanges`、`sourceChanges`、`onOperation`、`combinedSnapshot`，加上 `position` / `duration` / `buffered` / `volume` / `rate` / `progress` / `isPlaying` / `recovery`。

画面不必依赖 UI 包：`MediaPlayerView(handle: handle, fit: BoxFit.contain, enablePinchZoom: true)`（`renderer` 模块）只负责渲染、跟随 `backendChanges` 重建、并提供截图用的 `RepaintBoundary`；控制条与六套设计语言在 [media_core_ui](../media_core_ui/README.md)。

自己接引擎只需要实现契约：

```dart
final class MyAdapter extends PlayerAdapterBase implements PlayerVideo {
  static const PlayerAdapterCapabilities defaultCapabilities = PlayerAdapterCapabilities(
    supportsLive: true,
    supportedProtocols: {'https'},
    supportedFormats: {'mp4', 'm3u8'},
    compositeSupport: CompositeSupport.none,
  );

  @override
  Future<void> onOpen(PlayerSource source) async { /* 交给引擎 */ }

  @override
  Widget build() => /* 适配器自己持有 surface / texture */ const SizedBox.shrink();
}
```

`PlayerAdapter` 的抽象成员：`id` / `capabilities` / `state` / `position` / `duration` / `metrics` / `events` / `initialized` 与 `initialize` / `open` / `play` / `pause` / `stop` / `seek` / `setVolume` / `setRate` / `setAudioOnly` / `applyEngineOptions` / `captureFrame` / `close` / `dispose`。子类写的是 `onXxx` 钩子；命令串行化、代际门（过期异步结果丢弃）、事件准入由 `PlayerAdapterBase` 统一负责，所以四个适配包不会各自长出一套并发 bug。

多轨源（Bilibili 式 DASH 视频 + 音频两个 URL）走形状感知的入口：`kernel.createFromMedia(mediaSource)` 先由 `MediaSourcePlanner` 结合后端声明的 `compositeSupport` 给出 `DirectPlan` / `CompositePlan` / `UnsupportedPlan`，不支持就抛异常——把复合源塞给单 URL 引擎只会得到一条没有声音的画面，这里选择吵。`kernel.planFor(source)` 可以在创建之前只问"能不能播、由谁播"。

## 模块构成

`lib/` 下 45 个目录，44 个经 `lib/media_core.dart` 导出（`testing` 里的 fake 刻意不导出）。

| 组 | 目录 | 提供什么 |
| --- | --- | --- |
| 编排根 | `kernel` `runtime` `core` `factory` | `PlayerKernel`（注册后端、创建/释放、事件、池、预载、能力挂载）、`PlayerHandle`（单播放器门面）、`PlayerRuntime`（adapter + session + playback + geometry 的组合根）、`PlayerFactory` |
| 会话与串行化 | `session` `identity` `playback` `operation` `task` `state_machine` `concurrency` `reconciler` | `PlayerSession` + `GenerationId`（迟到的事件据此作废）、`PlaybackController` 与命令队列、`OperationTracker` / `TaskManager`、`PlayerReconciler`（期望态→实际态） |
| 恢复与降级 | `recovery` `fallback` `error` `result` | 唯一决策点 `RecoveryLadder`（`sameBackendReopen` → `nextLine` → `nextBackend` → 放弃）、`ErrorClassifier` / `PlayerErrorCode`、`Result` / `AsyncResult` |
| 池化与调度 | `pool` `preload` `slot` `coordinator` `visibility` | `PlayerPool`、`PlaybackPoolOrchestrator`（+ `PoolPlayerHost` / `PoolPlayerHandle` 接缝）、`PreloadManager`、`GlobalPlayerCoordinator`（player / playback / page / audio / resource / preload / lifecycle / presentation 八路）、`VisibilityController` |
| 能力与设备 | `adapter` `platform` `policy` `resource` `planning` `source` | 适配器契约与注册表/选择器、`PlatformProvider`（设备事实）、集中式 `PlayerPolicy`、`ResourceManager`（解码/带宽/温度→压力）、`SourceService`（解析 / 探测 / 校验链） |
| 数据面与呈现 | `renderer` `screenshot` `recording` `casting` `composition` `quality` `geometry` `presentation` `audio` | `MediaPlayerView`、双路截图（引擎抓帧 / 渲染面抓取 + `ScreenshotWriter`）、录制与投屏**契约**、时间线组合（`MediaTimeline` / `TimelineComposer`）、清晰度切换、视频几何与旋转、全屏/PiP/浮窗状态机、焦点与会话抽象 |
| 支撑设施 | `cache` `network` `diagnostics` `event` `bug` `reactive` `util` | `CacheManager`（内存 + `DiskCache`、LRU/FIFO 驱逐）、`NetworkManager` 与 `HttpHeaderSanitizer`、`DiagnosticsManager` / `PerformanceMonitor`、`PlayerEventBus`、`bug` 的故障注入、rxdart 之上的流工具 |

三条贯穿全仓库的规则：

- **能力靠声明**：`PlayerAdapterCapabilities` 是后端能力的唯一来源，`PlatformCapabilities` / `PlatformCodecCapabilities` 是设备事实的唯一来源（由探针填报），两者都保留"未知"的表达——未知不等于不支持。
- **一个决策点**：恢复只在 `RecoveryLadder` 一处决定（消费者用 `handle.reportFailure(...)` 上报、用 `recoveryEvents` 观察），换后端必须验证进度真的在推进。
- **序列化即正确性**：公开操作进队列按序执行，门是队列自身状态 + 代际守卫 + 操作注册表，不靠散落的布尔标志。

## 平台支持

本包是纯 Dart + Flutter widget，不含任何平台分支或原生代码，因此在 Flutter 支持的平台上都能编译运行：Android、iOS、macOS、Windows、Linux、Web。

"能播什么"由注册的引擎决定，平台差异都落在适配包里：media_kit 与 fvp 覆盖五个原生平台，ijk 与 better_player 只有移动端 / Android+iOS。Web 上 media_kit 走 HTML 元素，适配器会把 `supportsEngineOptions` / `supportsScreenshot` / 复合源声明收窄成 false（没有 `NativePlayer` 可写），这是刻意的诚实而不是功能缺失。

## 已知边界

说清楚哪些是契约而不是成品：

- `casting`、`recording` 只有模型与后端接口（`MediaCastBackend` / `RecordingBackend`）；DLNA 在 `media_core_cast_dlna`，FFmpegKit 录制在 `media_core_recording_ffmpeg`。
- `NetworkMonitor` 是接口 + `BaseNetworkMonitor` 骨架，仓库里唯一的实现是 `testing/fake_network.dart`；真实连通性要宿主或平台包注入，否则 `NetworkManager` 只是没有来源的缓存。
- `ThermalManager` 只做 `ThermalState` → `ResourcePressure` 的换算，温度值需要宿主调 `update()` 喂进来。
- `audio` 模块是 `AudioFocus` / `AudioSession` / `AudioRoute` 抽象，平台实现归 `media_core_native`（仍在推进）。
- 本包不提供 FLV 重写与回环中继：那部分在 `media_core_ingest`（`LoopbackIngestRelay` / `FfmpegIngestRelay` + `resolveIngestPlan`）。
- `lib/media_core.dart` 与 `lib/*/library.dart` 是生成的（`GENERATED MODULE LIBRARY` 头），新增模块时手工补一条导出。

## 测试

```bash
flutter test   # packages/media_core/test：41 个模块目录、约 290 个用例（代际作废、命令串行化、恢复梯级、池与预载、事件、规划与几何）
```

## 相关文档

- 仓库总览与包清单：[../../README.md](../../README.md)
- 架构与模块文档：[../../doc/zh-Hans/architecture.md](../../doc/zh-Hans/architecture.md) · [36 篇模块文档](../../doc/zh-Hans/README.md)（另有 en / zh-Hant 版本）
- 包内长文：[media_core_architecture_guide.md](media_core_architecture_guide.md)
- 引擎适配：[media_core_media_kit](../media_core_media_kit/README.md) · [media_core_fvp](../media_core_fvp/README.md) · [media_core_ijk_player](../media_core_ijk_player/README.md) · [media_core_better_player](../media_core_better_player/README.md)
- 基础设施：[media_core_logging](../media_core_logging/README.md) · [media_core_memory](../media_core_memory/README.md) · [media_core_native](../media_core_native/README.md)
