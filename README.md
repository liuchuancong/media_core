# media_core

跨平台可复用的 Flutter 播放器核心。37 个自包含模块 + 一个把它们全部串起来的编排层（kernel），加上按平台拆分的能力包。

> 📐 完整分层架构(模块职责、挂载点、数据流、恢复决策流):[架构总览](docs/zh-Hans/architecture.md) · [Architecture (EN)](docs/en/architecture.md)

## 架构总览

```text
PlayerSource
    │   SourceService（解析 / 校验 / 探测）
    ▼
PlayerAdapterSelector ──▶ PlayerAdapterRegistry（media_kit / ijk / video_player / native ...）
    │   按协议、格式、直播能力、优先级打分选出最优后端
    ▼
PlayerHandle ◀────────── PlayerKernel（编排根）
    │
    ├── PlayerAdapter            具体播放后端
    ├── PlayerSession            会话 + Generation（防止过期异步结果）
    ├── PlaybackController       播放状态机（命令串行化）
    ├── LifecycleController      生命周期（后台/前台）
    ├── RecoveryManager          错误自动重试（指数退避）
    ├── BackendFallback          重试耗尽后自动切换后端
    ├── GlobalPlayerCoordinator  音频 / 页面 / 资源 / 展示跨播放器协调
    ├── PlayerPool               播放器实例池（复用）
    ├── PreloadManager           预加载排队
    └── PlayerEventBus           全局归一化事件流
```

## 快速开始

```dart
import 'package:media_core/media_core.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:media_core_ijk_player/media_core_ijk_player.dart';

void main() {
  MediaKitPlayerAdapter.ensureInitialized();

  final kernel = PlayerKernel()
    ..registerBackend(MediaKitPlayerAdapter.defaultRegistration())
    ..registerBackend(IjkPlayerAdapter.defaultRegistration());

  runApp(MyApp(kernel: kernel));
}
```

播放：

```dart
final handle = await kernel.create(
  source: PlayerSource(
    id: SourceId('demo'),
    uri: Uri.parse('https://example.com/video.mp4'),
    protocol: SourceProtocol.https,
    format: SourceFormat.mp4,
  ),
  config: PlayerConfig.defaults.copyWith(autoPlay: true),
);

await handle.play();
await handle.seek(const Duration(seconds: 30));
await handle.setVolume(0.5);

// 订阅归一化事件（打开 / 播放 / 缓冲 / 恢复 / 降级 / 错误）
kernel.subscribe((event) => print('[${event.type.name}] ${event}'));

// 用完释放（或 kernel.acquire() 从实例池复用）
await kernel.release(handle.id);
```

## 错误自愈链路

adapter 报错后内核自动执行：

1. **恢复**：按 `PlayerConfig.maxRecoveryAttempts` 重试 open（指数退避，Generation 守卫防止旧代写新代）；
2. **降级**：重试耗尽后，`BackendFallback` 从注册表按优先级切换到下一个后端，保持进度 / 音量 / 倍速 / 播放状态；
3. **终态**：所有候选耗尽时发布 `critical` 级 `PlayerErrorEvent`。

整条链路全部通过 `PlayerEventBus` 发布 `recovery` / `fallback` 事件，可观测。

## 池化播放编排

`media_core` 的 `pool` 模块提供 `PlaybackPoolOrchestrator`:一个**有界播放器池**驱动列表/信息流/直播的播放决策。

- **交换源而非重建**:空闲播放器被重新指向下一个条目,解码器只建一次。"三个播放器覆盖无限列表"。
- **可见性驱动 + 迟滞**:宿主上报每条的可见比例,`playVisibilityThreshold` 之上播放、`pauseVisibilityThreshold` 之下暂停,两者之间不动,避免半可见条目在滑动中反复起停。
- **邻居预热**:`preloadCount` 决定活动条目两侧各保持几个已打开(暂停)的播放器,滑动即换源。
- **按压力收缩**:`ResourcePressure` 上升时先放弃预热(warning 减半、critical 归零),再释放空闲播放器。
- **可配回收**:`idleTimeout`/`keepWarm`/`warmSize`/`enableRecycle` 决定空闲播放器回池还是销毁。

播放器来自宿主实现的两个接缝:`PoolPlayerHost`(取用/归还)与 `PoolPlayerHandle`(换源/播放/暂停/回收/音量)。`KernelPoolPlayerHost` 适配内核实例池;`PlayerPoolConfig` 是唯一的配置面,各功能包给出推荐预设(`FeedConfig.recommendedPoolConfig`、`PlaybackListConfig.recommendedPoolConfig`、`LivePoolPolicy.toPoolConfig()`)。

## 后端适配包

| 包                           | 后端               | 说明                        |
| ---------------------------- | ------------------ | --------------------------- |
| `media_core_media_kit`     | media_kit          | 全能后端，协议/格式覆盖最广 |
| `media_core_ijk_player`    | ijk (niuma_player) | FLV / H.265，移动端         |
| `media_core_better_player` | 官方 video_player  | 轻量、纯 Flutter 生态       |
| `media_core_native`        | 平台原生           | 平台播放器                  |

每个适配包提供 `XxxAdapterFactory` 与 `registerXxxRegistry()` / `defaultRegistration()` 两种注册方式。

## 文档

- 中文：[docs/zh-Hans/README.md](docs/zh-Hans/README.md)
- English: [docs/en/README.md](docs/en/README.md)
- 繁體中文：[docs/zh-Hant/README.md](docs/zh-Hant/README.md)

## 能力包

后端负责"能播",能力包负责"播得完整"。每个能力包实现核心模块定义好的契约,按平台与需求单独引入。

| 包 | 能力 | 说明 |
| --- | --- | --- |
| `media_core_fullscreen` | 全屏 | 两种变体:系统全屏(桌面窗口/移动沉浸)与当前窗口全屏;含竖屏/横屏适配策略 |
| `media_core_pip` | 画中画 | **系统窗口**:桌面置顶小窗(可锁/不锁宽高比) + Android 系统画中画;移动端可请求不可退出(平台事实) |
| `media_core_floating` | 应用内小窗 | 应用自身 widget 树内的可拖拽、贴边吸附视频浮层;纯几何逻辑,无平台分支(不涉及系统窗口) |
| `media_core_danmaku` | 弹幕 | 传输契约 + 消息归一化 + 去重/积压闸门 + 内容过滤 + 会话围栏 |
| `media_core_live` | 直播 | 线路/引擎扫描、卡顿看门狗、退避重试 |
| `media_core_feed` | 抖音式上下滑 | 共用一个播放器换源、滑动吸附、下一项预载 |
| `media_core_list_playback` | 列表播放 | 单窗口上/下滑切换,按条目记忆进度,返回时续播 |
| `media_core_audio` | 音频会话 | 音频焦点、会话与后台播放接线 |

内核只保留与平台无关的基础设施(缓存、协调器、录制抽象、策略、池、预载等)与各能力共享的状态机。

## Workspace 布局

```text
packages/
  media_core/                       核心（本包，40 个模块）
  media_core_media_kit/             media_kit 适配
  media_core_better_player/         video_player 适配
  media_core_ijk_player/            ijk (niuma_player) 适配
  media_core_fvp/                   fvp 适配
  media_core_native/                原生适配
  media_core_audio/                 音频能力
  media_core_presentation/          共享呈现层(窗口接缝 + 浮层组件)
  media_core_fullscreen/            全屏(两种变体 + 方向策略)
  media_core_pip/                   画中画(系统窗口:桌面小窗 + 安卓系统 PiP)
  media_core_floating/              应用内小窗(浮层 widget + 摆位/拖拽/吸附)
  media_core_danmaku/               弹幕
  media_core_live/                  直播编排
  media_core_feed/                  抖音式上下滑
  media_core_list_playback/         列表播放(进度续播)
examples/example/                   示例 App
```
