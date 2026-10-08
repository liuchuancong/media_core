# media_core_live

`media_core` 的直播（不可 seek）播放编排：线路 × 引擎扫描、停顿看门狗与恢复重开。

## 定位

内核的恢复阶梯是为可 seek 的回放设计的 —— 那里"重开一次"约等于"恢复"。直播不是：一条线路挂了要换下一条，所有线路都挂了要换引擎，而平台给的地址往往是**一次性**的。本包把直播的恢复决策整个拿走，并对它创建的句柄调用 `handle.setRecoveryEnabled(false)`，于是**恢复路径只有一条**，全部能在 `live_playback_controller.dart` 与其两个 `part` 文件里读完。

- **扫描（sweep）**：先换线；线用尽才换引擎，换引擎后从"用户正在看的那一条"重新开始。引擎切换是 **staged** 的 —— 新引擎在旁边 open、play、验证通过之后才 commit，旧引擎在此之前一直放着。挂载的画面因此只在新引擎已经解出一帧时才换，黑屏不是一整段首帧时间。
- **验证才是判据**：`open` 不抛异常不等于播起来了。成功的门槛是播放位置出现过**任意一次正向推进**（有些直播源 demuxer 时钟从 0 附近起，画面在放而位置只爬几十毫秒），窗口就是 `LiveWatchdogs.sourceReadyTimeout` —— 一个问题只给一个期限，不再另设更严的私有常量。
- **看门狗是纯探测器**：它不持有句柄、不调 `play()`、不 await 后端操作。`LiveStallKind` 说明观察到哪种停顿（无播放态、无视频帧、缓冲不退、位置停止前进），需要立刻执行的恢复命令以 `LiveWatchdogRecoveryAction` 交回播放所有者 —— 也就是 `LivePlaybackController` 自己；`positionStallTimeout` 是最后一道兜底，因为每个引擎都上报位置，而帧心跳只有部分引擎有。
- **单槽任务队列**：`play` / `switchLine` / `retry` / `pause` / `resume` / `close` / 恢复，全都是 `TaskManager(maxConcurrentTasks: 1)` 上的任务。于是"两次切换互相踩"这类经典竞态在结构上不存在：用户动作会直接把排在队里的恢复挤掉，重复的 `play()` 在第二个进来时把第一个从队列里取消。
- **一次性 URL 的两个插入口**：`onEngineFallbackSources`（换引擎之前）与 `onRecoverySources`（恢复重开之前）。返回新线路就从头扫，返回空列表就沿用现有线路；resolver 抛异常时保留线路并如实报停顿，不会卡在等平台上。

**扫描内的候选切换没有退避延迟**：一次 `play` 任务里把所有允许的组合扫完，扫空后 `onError` 只发一次、不自动重来。反复失败的节奏由宿主掌握（自己决定何时再 `retry()` 或再 `play()`），本包不替它造一个后台重连循环。

## 用法

```dart
final controller = LivePlaybackController(
  kernel,
  // 换引擎前：签名线路已被上一个引擎消耗掉，向平台重新要一批
  onEngineFallbackSources: (nextEngine, current) => platform.fetchLines(),
  // 恢复重开前：地址按平台的时钟过期，而不是按播放器的
  onRecoverySources: (current) => platform.refreshUrls(),
);

controller.onStateChanged.listen(renderState);
controller.onError.listen(showRetryButton);          // 每条扫空的 sweep 恰好一次
controller.onHandleChanged.listen(rebindSurface);    // 引擎切换后必须重绑：旧句柄已 dispose

await controller.play(LiveSourceRequest(sources: lines));
// 只有字符串时：LiveSourceRequest.fromUrls(urls, headers: {'referer': ...})
// —— protocol/format 是从 scheme 与扩展名推断的，能自己构造就别用推断

await controller.switchLine(2);      // 手动换线，也是一次排队任务
await controller.setAudioOnly(true); // 音频模式：无视频轨，帧看门狗整个解除
controller.noteBackgrounded();       // 后台自动暂停是系统意图，不该被读成网络故障
```

看门狗期限可以逐路调，`sourceReadyTimeout` 传零即关闭该项：

```dart
LivePlaybackController(
  kernel,
  watchdogs: LiveWatchdogs(
    sourceReadyTimeout: const Duration(seconds: 12), // 也决定 sweep 的验证窗口
    positionStallTimeout: const Duration(seconds: 20),
  ),
);
```

想让**备用线路提前开着**（切线时不再冷启动），把池配置交给宿主自己的池：

```dart
final pool = PlaybackPoolOrchestrator(
  host: myPoolPlayerHost,
  config: LivePoolPolicy.defaults.toPoolConfig(),   // 1 个备用、空闲 15s 就放
);
```

live 的池值比 feed 紧得多：一条暖着没人看的线路就是一张带宽账单。

## 平台支持

纯 Dart 包：pubspec 里没有 `flutter.plugin` 段，没有平台代码，只依赖 `media_core` 与 `rxdart`（rxdart 用在看门狗的调度上）。因此可用平台 = 内核注册了后端适配器的平台，引擎候选顺序也来自 `kernel.selector.candidatesFor(...)` 打分结果，本包不写死任何引擎名。

- **引擎能力差异被如实对待**：帧心跳只在适配器声明 `PlayerAdapterCapabilities.supportsVideoFrameProgress` 时才作为判据；位置看门狗等当前引擎**第一次上报位置**之后才开始计时，于是"不上报位置的引擎"不会被误判为卡死。
- **`duration` 不做修饰**：引擎报什么就给什么，有的直播线回 0、有的回"开播以来的时长"。要判断"这是直播吗"应该读源声明，不是这个值。
- 探针能给的答案（设备能否硬解这个编码、低内存设备的前向缓冲上限）在 [../media_core_native](../media_core_native)；本包只问"有没有播起来"。

## 相关文档

- 内核、句柄与恢复阶梯：[../media_core](../media_core)
- 停顿与切换的决策日志（`recovery` / `fallback` 分类）：[../media_core_logging](../media_core_logging)
- 候选线路的内存记账（`MemoryModule.live`）：[../media_core_memory](../media_core_memory)
- 竖屏信息流的另一种"下一步"语义：[../media_core_feed](../media_core_feed)
- 仓库总览：[../../README.md](../../README.md)
