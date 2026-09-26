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

## 多画面同看

`media_core_multiview` 把 N 路直播放进一个网格，处理监控场景真正要处理的事:

- **逐格健康度**:每格独立状态(空/起播/播放中/未开播/恢复中/失败)与失败种类(解析/起播/卡顿),关掉一格的自动重试预算有界——一直重试死流只烧流量和电。
- **唯一音频归属**:`MultiviewAudioMode` 提供独占(仅焦点格出声)/静音/混合;切换焦点时先静音其余再放开目标,失败格不会漏音。音量与静音走内核的池句柄。
- **视频焦点与画质**:焦点格取最高档、其余取最低档(可用 `MultiviewQualityResolver` 由宿主接站点换档);`focusFirst`/`uniform` 两种策略。
- **解码/内存预算**:内核上报 `ResourcePressure`,按 `MultiviewBudgetPolicy` 收缩——超标时只留焦点格、或交给平台丢帧、或直接拒绝新增格子,并在快照里说明原因。
- **逐格弹幕**:每格一个 `DanmakuOverlaySession`(队列按表面隔离),默认只喂焦点格;`focusedDanmaku` 供宿主的 sink 分流。
- **巡更轮巡**:`patrolEnabled` 按间隔轮换焦点与音频,可跳过未开播/失败的格子——正是监控墙的轮巡。
- **逐格播放列表**:某格可绑定一串房间,失败或结束时自动前进到下一个在线房间。
- **播放器来自内核池**:每格经 `PoolPlayerHost` 取用/归还,换房间复用热播放器;清格即归还。
- **交接**:`handOverCell(index, handOver)` 把某格播放器交给 PiP/小窗会话控制器,流不重启。

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
| `media_core_recording_ffmpeg` | 录播 | FFmpegKit 分段 MPEG-TS 录制 + CSV 日志;失败只丢几秒而非整场 |
| `media_core_download` | 下载 | 有界并发队列、断点续传(先校验再续)、重试预算与进度 |
| `media_core_multiview` | 多画面同看 | 监控式视频墙:逐格健康度、唯一音频归属、解码预算、逐格弹幕、巡更轮巡、逐格播放列表 |
| `media_core_logging` | 分级日志 | 全局日志枢纽:分级/分类开关、多 sink 并行(控制台/内存环形缓冲/文件轮转)、开发者过滤与节流、Zone 作用域字段 |
| `media_core_memory` | 内存记账 | 双视角内存监控:各模块按实例申报占用(可求和/可撤回) + 设备实测快照;预算阈值驱动的四级压力与资源层桥接 |

内核只保留与平台无关的基础设施(缓存、协调器、录制抽象、策略、池、预载等)与各能力共享的状态机。

### 分级日志

所有模块通过 `MediaCoreLog` 打日志,默认**完全静默**(`LogLevel.nothing`),由宿主显式开启:

```dart
MediaCoreLog.level = LogLevel.debug;                             // 全局开到 debug
MediaCoreLog.setCategoryLevel(LogCategory.pool, LogLevel.trace); // 只把播放器池开到 trace
final memory = MediaCoreLog.attachMemorySink(capacity: 500);     // 控制台之外再收一份到内存
MediaCoreLog.attachFileSink(File('${dir}/media_core.log'));      // 或落盘(带尺寸轮转)

LogScope.run({'roomId': room.id}, () => player.open(source));    // 作用域内每条日志都带上房间号
```

模块内部用绑定了分类的 logger,调用点不必重复写分类;热路径可以先判断再组装字段:

```dart
final _log = MediaCoreLog.of(LogCategory.multiview);
if (_log.isDebugEnabled) _log.debug('cell assigned', fields: {'index': index});
```

分类(`LogCategory`)与模块一一对应:内核与生命周期(`player`/`lifecycle`)、播放与缓冲(`playback`/`buffering`)、源解析(`source`)、呈现与三个小窗包(`presentation`)、恢复与回退(`recovery`/`fallback`)、录制(`recording`)、下载(`download`)、弹幕(`danmaku`)、多画面(`multiview`)、播放器池(`pool`)、资源与内存(`memory`/`performance`)、日志子系统自身(`logging`)。因此排查单个问题时只需把对应分类调高,而不是被其它模块的 trace 淹没。

### 内存监控

两个视角,一个回答"谁在用",一个回答"一共用了多少":

```dart
final _memory = MediaCoreMemory.of(MemoryModule.pool);           // 模块侧:取账本
_memory.report(_key, items: players, bytes: estimated, note: '4 active, 6 warm');

if (MediaCoreMemory.pressure.shouldStopPreload) return;          // 策略侧:先问压力

MediaCoreMemory.attachDeviceProvider(myPlatformMemoryReader);    // 诊断侧:设备真值
print(MediaCoreMemory.report().describe());
```

没有任何 Dart API 能报出解码器、纹理或原生播放器占了多少字节,所以模块上报的是**申报值**(`MemoryEstimates` 中刻意保守的估算),用途是排序与驱动预算;设备真值来自宿主安装的平台 provider;而磁盘缓存、下载、录像是**实测值**——它们本来就知道自己写了多少字节。压力按 512 MiB / 70% / 85% 折算成四级,等级变化写进 `memory` 分类日志;资源层通过桥接把它折算进自己的 `ResourcePressure`,与解码器、带宽、温度压力取最大值。

模块账户按**贡献者**分别记账再求和:一面 3×3 视频墙的 9 个弹幕队列相加,而不是只留最后一个;实例销毁时 `withdraw` 撤掉自己那一份。

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
  media_core_recording_ffmpeg/      录播(FFmpegKit 分段录制)
  media_core_download/              下载(队列 + 续传 + 重试)
  media_core_multiview/             多画面同看(监控式视频墙)
  media_core_logging/               分级日志(枢纽 + sink + 过滤/节流/作用域)
  media_core_memory/                内存记账(模块账本 + 压力预算 + 设备快照)
examples/example/                   示例 App
```
