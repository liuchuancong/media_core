# media_core_better_player

以 [better_player_plus](https://pub.dev/packages/better_player_plus) 为引擎的 media_core 后端适配器：**已经实现并可用**，不是脚手架。

## 定位

`BetterPlayerAdapter` 继承 `PlayerAdapterBase`、实现 `PlayerVideo`，把 better_player_plus 接到 [media_core](../media_core) 的适配器契约上；会话、命令串行化、恢复梯级与事件归一化全部来自核心，本包只管引擎细节。

引擎链条要说清楚：better_player_plus 是建立在 `video_player` 之上的播放器封装（Android 走 AndroidX Media3 / ExoPlayer，iOS 走 AVPlayer），本包**不直接**使用 `video_player` 的 API——控制器是 `BetterPlayerController`，数据源是 `BetterPlayerDataSource`。因此能力上限由这条链决定：

- **能做的**：网络与文件源、`play/pause/stop/seek/setVolume/setRate`、直播源标记（`liveStream` 取自 `source.isLive`）、请求头透传、通过 `setOverriddenFit` 应用画面比例。
- **做不到的**（在 `defaultCapabilities` 里就写成 false，不让核心去试）：`supportsAudioOnly`（better_player_plus 任何一层都没有关闭视频轨的入口，解码器关不掉）、`supportsScreenshot`（引擎无抓帧 API，截图由核心退回渲染面抓取）、`supportsVideoFrameProgress`、`supportsBufferingProgress`（缓冲只报进度字节，不报比例）、`supportsPlaylist` / 轨道与字幕选择、`supportsSoftwareDecoder`。
- **复合源刻意声明 `CompositeSupport.none`**：`BetterPlayerDataSource` 只收一个 URI，DASH 双轨交给它就会只出声不办事——宁可让规划层回答 `UnsupportedPlan`。这条由 `test/composite_capability_test.dart` 钉住。

`onApplyEngineOptions` 只有四个键能即时生效：`volume` / `speed` / `looping` / `mixWithOthers`；其余一律回答 `needsRebuild`，因为 better_player 的配置在控制器构造时就锁死。同理，`updateConfiguration(...)` 只影响**下一个**控制器，运行中改配置要在核心侧 `handle.rebuildEngine()`。

## 用法

```dart
import 'package:media_core/media_core.dart';
import 'package:media_core_better_player/media_core_better_player.dart';

final kernel = PlayerKernel()
  ..registerBackend(const BetterPlayerAdapterFactory().registration());   // id 'better_player'，默认 priority 80

// 引擎原生配置原样透传；configureDataSource 是每次 open 前的最后一跳改写。
final factory = BetterPlayerAdapterFactory(
  configuration: BetterPlayerConfiguration(autoPlay: true, handleLifecycle: false),
  configureDataSource: (source, dataSource) => BetterPlayerDataSource(
    dataSource.type,
    dataSource.url,
    headers: const <String, String>{'Referer': 'https://example.com'},
    liveStream: source.isLive,
  ),
);   // 这个工厂实例可以 kernel.registerBackend(factory.registration())，也可以按需注入

final handle = await kernel.create(
  source: PlayerSource(id: SourceId('clip'), uri: Uri.parse('https://example.com/clip.mp4')),
  config: const PlayerConfig(autoPlay: true),
  preferredBackend: kBetterPlayerBackendId,
);
```

画面由适配器自己给：`build()` 返回 `BetterPlayer(controller: ...)`，`available` 在控制器存在前为 false，`attach()` / `detach()` 是空操作（surface 生命周期归 BetterPlayer 自己）。宿主通常只把 handle 交给 `MediaPlayerView` 或 `media_core_ui`，不需要直接碰这些。

三个入口都在：`BetterPlayerAdapterFactory().registration()`（进 `PlayerKernel.registerBackend`）、`registerBetterPlayerRegistry(registry)`、`registerBetterPlayerFactory(defaultFactory)`。

本包 `package:media_core_better_player/media_core_better_player.dart` 顺带再导出 `package:better_player_plus/better_player_plus.dart`，宿主只依赖本适配器就能拿到 `BetterPlayerController` 等引擎类型。

## 两处引擎语义

- **缓冲抖动不出门**：better_player 的 `onIsPlayingChanged` 把 BUFFERING 折成"没在播"，直播一卡就以缓冲频率成对抛 pause/play。适配器用 `_playingNow` 闩掉这些伪变化，卡顿只通过 `PlayerAdapterEvent.buffering` 表达——否则下游（壁纸层、后台解码）会跟着每 tick 重建。
- **释放要强制**：`onDispose` 调 `dispose(forceDispose: true)`。better_player 在 `autoDispose: false` 时会提前返回，原生播放器（解码器、surface、音频）活下来，下一次引擎切换就得和它抢硬解单元，关掉的房间还会在 UI 背后继续出声。

同一处原生失败可能既以 exception 事件出现、又落在 `videoPlayerController.value.hasError` 上，适配器按消息去重，只让一条进核心；position / duration / buffered 不在引擎事件里，靠被包裹控制器的 value 做差值上报。

## 平台支持

跟随 better_player_plus 声明的平台：**Android 与 iOS**。桌面（Windows / macOS / Linux）与 Web 不在其中——需要这些平台请注册 [media_core_media_kit](../media_core_media_kit/README.md) 或 [media_core_fvp](../media_core_fvp/README.md)，本包可以与它们并存，由核心的能力选择器按协议、格式与优先级打分决定用谁。

asset 源本包**不支持**：装上的 better_player_plus 只有 `network` / `file` / `memory` 三种数据源类型，没有 asset。`_resolveSource` 对它返回 null，`onOpen` 因此抛 `StateError` 而不是把垃圾 URI 交给引擎；确实要播内置资源，得先把字节读出来走 memory 数据源。

## 相关文档

- 核心与契约：[../media_core/README.md](../media_core/README.md)（`PlayerAdapter` / `PlayerVideo` / `PlayerAdapterCapabilities` 在 `lib/adapter/`）
- 同层适配器：[media_core_media_kit](../media_core_media_kit/README.md) · [media_core_fvp](../media_core_fvp/README.md) · [media_core_ijk_player](../media_core_ijk_player/README.md)
- 仓库总览：[../../README.md](../../README.md)
