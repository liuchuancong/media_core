# Media Core 架构总览

> 本文描述 media_core 的完整分层架构:模块职责、挂载关系、一次播放的完整数据流、故障恢复的决策流,以及扩展新后端的方法。

## 一、分层总图

```text
┌─────────────────────────────────────────────────────────────────┐
│ 应用层(宿主 App 直接使用的入口)                                  │
│                                                                 │
│  PlayerHandle(单播放器)   LivePlaybackController(直播)          │
│  FeedPlayerController(上下滑)  MediaPlayerView(渲染 Widget)      │
│  PlayerVisibilityBinding(可见性联动)                             │
└──────────────┬──────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│ kernel 编排层  PlayerKernel                                      │
│  · create/release:选引擎 → 建 handle → 注册各处                  │
│  · preload / pool / coordinator / eventBus 汇聚点                │
│  · attachAudio / attachPresentation 能力驱动                     │
└──────────────┬──────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│ handle 运行时层  PlayerHandle(每逻辑播放器一个)                   │
│                                                                 │
│  PlayerRuntime(组合根)                                          │
│   ├ PlayerAdapter(引擎实例,可被恢复梯级替换)                      │
│   ├ PlayerSession + SessionController(会话状态)                  │
│   ├ PlaybackController(命令/位置/音量/倍速镜像)                   │
│   ├ GeometryController(视频尺寸/宽高比)                          │
│   └ PlayerPlaybackBinding / PlayerGeometryBinding(事件→状态镜像)  │
│                                                                 │
│  handle 自有模块                                                 │
│   ├ LifecycleController(create→init→activate→pause→detach)       │
│   ├ RecoveryLadder(唯一恢复决策点) + RecoveryTarget(执行侧)       │
│   ├ OperationRegistry/Tracker(操作记录,可观测)                   │
│   └ 操作串行队列 + 生命周期代数(generation)                       │
└──────────────┬──────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│ adapter 后端抽象层                                               │
│  PlayerAdapter(统一引擎契约)   PlayerAdapterBase(模板基类)        │
│  PlayerAdapterRegistry(注册)  PlayerAdapterSelector(打分选择)    │
│  PlayerAdapterCapabilities   PlayerAdapterEvent(统一事件)        │
│  PlayerVideo(视频 widget 输出接口)                               │
└─────────────────────────────────────────────────────────────────┘

基础设施层(被上述层消费):identity / core / source / error /
event / policy / platform / operation / task / diagnostics …
独立积木(按需 import,不挂在主链路):cache / network / recording /
slot / state_machine / reconciler / bug / factory / concurrency /
reactive / result / util / fallback
```

## 二、模块职责与挂载点(权威表)

### 主链路(全部已接线)

| 模块 | 职责 | 挂在哪里 | 联动点 |
| --- | --- | --- | --- |
| `identity` | 强类型 ID | 被所有层引用 | `PlayerId/SessionId/SourceId/GenerationId` 贯穿每个事件 |
| `core` | Player 域模型、PlayerConfig、PlayerState | kernel 创建 Player | `Player.create()` → handle.id |
| `source` | **PlayerSource**:uri/protocol/format/headers/type | adapter.open 的入参 | selector 打分、SessionContext、恢复换线都以它为键 |
| `adapter` | 引擎契约 + 注册 + 选择 + 能力 | PlayerRuntime 持有实例 | `open(source)`/`play()`/统一事件流/`PlayerVideo.build()` |
| `runtime` | 组合根:adapter+session+playback+geometry+镜像绑定 | PlayerHandle 内部创建 | `replaceAdapter()` 支持换引擎不断流 |
| `session` | 会话上下文/状态/快照 | PlayerRuntime | `open(source)` 重建 SessionContext(带 sourceId+generation) |
| `playback` | 命令与播放状态镜像 | PlayerRuntime | Binding 把 Playing/Paused/Position 变成 PlaybackState |
| `geometry` | 视频尺寸/宽高比 | PlayerRuntime | VideoSize 事件 → MediaPlayerView 的 AspectRatio |
| `lifecycle` | 播放器生命周期状态机 | PlayerHandle | play/pause/activate/deactivate 驱动转移 |
| `recovery` | 恢复梯级(决策+执行) | PlayerHandle(唯一) | adapter 报错 → reportFailure → 梯级 → reopen/swap |
| `operation` | 操作记录 | PlayerHandle | `handle.onOperation`:每个生命周期方法一条记录 |
| `event` | 全局事件总线 | PlayerKernel | handle 的 `_publish` 归一化事件 |
| `coordinator` | 跨播放器协调(8 个子协调器) | PlayerKernel | `_registerEverywhere` 注册每个 handle |
| `pool` | 实例池 | PlayerKernel | `acquire/recycle` 软复用 |
| `preload` | 预载登记 | PlayerKernel | `kernel.preload(source)`;feed 滑动时预载下一项 |
| `presentation` | 全屏/PiP/悬浮状态机 | kernel + coordinator | `attachPresentation(driver)` 后 `enterFullscreen` 等 |
| `policy` / `platform` | 跨模块策略 / 平台描述 | SessionContext | 随 source 传递 |
| `task` | 任务队列原语 | LivePlaybackController | 直播所有动作=单槽队列里的 task |
| `diagnostics` | 日志枢纽 MediaCoreLog | 所有层 | 每个关键路径都有结构化日志 |

### 应用层入口(三选一或组合)

| 入口 | 用途 | 底层 |
| --- | --- | --- |
| `PlayerKernel.create()` → `PlayerHandle` | 点播/通用播放器 | 完整主链路 |
| `LivePlaybackController` | 直播:线路/引擎扫描 + watchdog | 主链路 + task 队列;关闭 handle 自身梯级,保证单恢复路径 |
| `FeedPlayerController` | 抖音式上下滑 | 共用一个 handle 换源,下一项进 preload |
| `MediaPlayerView` | 渲染 | 读 `adapter as PlayerVideo` 的 widget,跟随 backendChanges 重建 |
| `PlayerVisibilityBinding` | 可见性自动暂停/恢复 | VisibilityController → handle.pause/play |
| `DanmakuController` | 直播弹幕:传输接入 + 过滤 + 会话围栏 | 独立于主链路:宿主提供 `DanmakuTransport` 与 `DanmakuSink` |

### 独立积木(不挂在主链路,按需 import)

`cache`、`network`、`recording`、`slot`、`state_machine`、`reconciler`、`bug`(故障注入)、`concurrency`、`reactive`、`result`、`util`。这些是零依赖通用件;`factory` 现在只负责"创建逻辑 Player 身份"(`PlayerFactory`/`DefaultPlayerFactory`),后端注册与选择统一由 `adapter` 模块承担,不再重复。

## 三、一次播放的完整数据流

```text
App: kernel.create(config, source, preferredBackend)
 1. SourceService.resolve(source)(可选解析真实地址)
 2. selector.scoreTable(source) → 选出最高分引擎(协议/格式/live 能力打分)
 3. Player.create() + adapter factory.create() + PlayerRuntime 组装
 4. handle.initialize() → adapter.initialize() → lifecycle create+initialize
 5. _registerEverywhere:coordinator/player/playback/lifecycle + pool 登记

App: handle.open(source)
 6. _invalidateOperations():代数+1,作废在途操作
 7. ladder.reset() → sessionController.recreateGeneration()
 8. session.updateContext(SessionContext(sourceId, generationId, source…))
 9. adapter.open(source)   ← PlayerSource 在此真正进入引擎
10. 应用 config.volume/rate + 排队的 pending 值 + mute/audioOnly
11. autoPlay → _playInternal:adapter.play → playback.play
    → sessionController.play → lifecycle.activate → 事件总线 'play'

App: MediaPlayerView(handle)
12. adapter as PlayerVideo → build() 的 widget 进 widget 树
13. VideoSize 事件 → geometry → AspectRatio 自适应

引擎事件(播放中)
14. adapter.events → 三个消费者并行:
    PlayerPlaybackBinding → playback 状态镜像
    PlayerGeometryBinding → geometry 镜像
    handle._onAdapterEvent → session 转移 + 事件总线 + 完成循环(loop)
```

## 四、故障恢复决策流(唯一决策点)

```text
任何失败源(适配器错误/看门狗停滞/打开抛错/位置不前进)
        │  reportFailure(RecoveryFailure)   ← 唯一入口
        ▼
PlayerHandle 持有的 RecoveryLadder(决策)
        │ 按 DefaultRecoveryLadderPolicy 生成梯级:
        ▼
[同引擎原样重开] → [换线路(PlayerSource 候选)] → [换引擎] → 报告耗尽
        │ 执行(RecoveryTarget,handle 实现)
        ▼
_reopenOnCurrentBackend / _swapTo(先装配新引擎、验活、再切换)
        │ 每步 _verifyPlayback:8 秒内位置必须前进,否则视为失败继续爬梯
        ▼
耗尽 → recoveryEvents 'exhausted' + 事件总线 fatal → 调用方决定(换片源/提示)
```

直播模式例外:LivePlaybackController 关闭 handle 梯级(`setRecoveryEnabled(false)`),在自己的单槽 task 队列里跑等价的"同引擎换线 → 换引擎"扫描 + watchdog(位置停滞是全引擎通用的停滞探测器),失败只上报一次到 `onError`。

## 五、扩展:接入一个新播放引擎

```dart
class MyEngineAdapter extends PlayerAdapterBase implements PlayerVideo {
  // 1. 实现 onOpen/onPlay/onSeek/… 模板方法,把引擎事件翻译为
  //    emitPlaying/emitPositionChanged/… 统一事件
  // 2. implements PlayerVideo:available + build() 返回视频 widget
  // 3. 声明能力(协议/格式/live/音轨),打分选择据此决策
}

final registration = PlayerAdapterRegistration(
  id: 'my_engine',
  factory: PlayerAdapterFactory.simple(() => MyEngineAdapter()),
  capabilities: …,
  priority: 50,
);

final kernel = PlayerKernel()..registerBackend(registration);
// selector 会自动把它纳入打分;恢复梯级自动可把它当候选引擎
```

宿主 App 不感知这些:同一份 `PlayerSource`、同一套 `handle.play()`/`MediaPlayerView`。

## 六、设计不变量(改代码前先读)

1. **恢复只有一个决策点**:RecoveryLadder 只在 PlayerHandle 内构造;其他模块只能 `reportFailure`。
2. **PlayerSource 是选择的唯一输入**:别把裸 URL 塞进框架重解析;协议/格式/headers 在 source 上声明。
3. **playIntent 高于镜像**:自动起播的引擎要 `declarePlayIntent(true)`,否则恢复后会误判暂停。
4. **换引擎必须验活**:open 返回≠播放,位置前进才是成功(`_verifyPlayback`)。
5. **操作串行 + 代数失效**:`_enqueue` 串行队列 + `_operationGeneration` 保证旧操作不能提交状态。
6. **facade 事件流稳定**:`adapterEvents/backendChanges/sourceChanges` 跨引擎切换保持有效,消费方不许持有旧 adapter。
