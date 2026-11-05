# iOS 锁屏 / 灵动岛歌词（Live Activity）可行性梳理

结论先行：**可行，且与现有架构严丝合缝**。桌面歌词走不了 iOS 是因为"悬浮窗"这堵墙，
而 Live Activity 是 Apple **唯一开放**的"在应用之外展示实时文本"的通道——锁屏上的当前歌词行 +
进度条 + 灵动岛紧凑视图，正是 Apple Music 自己锁屏歌词走的机制。

## 1. 平台事实（决定设计与边界）

- **ActivityKit，iOS 16.1+**（灵动岛内容需 16.1+，锁屏 Live Activity 16.0 即有；宿主可把
  16.0 以下当 unsupported，与 transport 的 `isSupported()` 契约一致）。
- **UI 必须是宿主 App 里的 Widget Extension**（SwiftUI，`ActivityConfiguration`）。
  这条是硬约束：Flutter 无法绘制锁屏表面，插件包只能传状态，画什么、什么品牌风格由宿主的
  Extension 决定。也就是说 media_core 能做"驱动 + 数据契约 + Dart API"，**宿主必须加一个
  Widget Extension**（纯 Swift，约几十行模板）。
- **更新预算宽松**：App 在前台或后台活跃播放时，本地 `Activity.update()` 没有次数限制——
  歌词逐行更新正是本地更新；App 被杀后的远程推送续更（APNs）不需要（音乐场景 App 必然活着）。
- **生命周期**：系统最长保留 8 小时活跃 + 12 小时结束态，远超一首歌/一场播放；音频 App 还可用
  `NSSupportsLiveActivities-FrequentUpdates` 提高更新调度优先级。
- **Flutter 侧渲染不受影响**：Activity 展示期间 App 照常后台播放，与 `flutter_media_session`
  的锁屏控制（上一首/下一首）并存——锁屏上会出现"媒体控制 + 歌词 Activity"两块，体验与
  Apple Music 一致。

## 2. 与现有架构的接缝

桌面歌词已经把"歌词实时展示"抽象成了一个平台缝隙
（`lib/src/desktop_lyric/desktop_lyric_transport.dart`）：

```text
DesktopLyricController（行解析/进度推进/响度）
        │ update(DesktopLyricState)
        ▼
DesktopLyricTransport          ← 唯一的接缝
  ├─ MethodChannelDesktopLyricTransport   android / win / mac / linux 悬浮窗
  └─ NoopDesktopLyricTransport            其余平台 isSupported() == false
```

iOS 的方案就是**再加一个实现**：

```text
  └─ LiveActivityLyricTransport            iOS 16.1+，走 ActivityKit
```

- `isSupported()`：iOS 16.1+ 且宿主声明了 `NSSupportsLiveActivities` 才返回 true，
  否则自动落到 Noop——宿主什么也不用改就能编译运行，符合"未知 ≠ 不支持、如实上报"。
- `show()` = `Activity.request(attributes:content:)`；`update()` = `Activity.update()`；
  `hide()` = `Activity.end(disposal:)`。语义一一对应，控制器零改动。
- `setLevels()`（响度柱）在锁屏 Activity 上无意义，实现为 no-op（接口允许）。
- 数据面沿用 `DesktopLyricState` 的字段映射成 Activity 的 state：
  `text`（当前行）、下一行预览、`isPaused`、曲目名/歌手（新字段，见 §4）。

## 3. 原生通道怎么做

两条路，建议 **B**：

- **A. pub 的 `live_activities` 插件**：功能全（图片、深链、push token），但要求宿主按它的
  约定建 Extension、带一套通用 UI 模板；歌词场景用不到大半能力，且多一层第三方依赖。
- **B. 自带一个极薄 method channel**（推荐）：`MediaCoreAudioPlugin` 已有 iOS 实现
  （`MediaCoreAudioPlugin` 类），加三个方法 `lyricActivityStart/Update/End`，Swift 侧各
  十几行 ActivityKit 调用。UI 状态契约就是 `Codable` 的几个字段——宿主的 Widget Extension
  解同一个 JSON。依赖面为零，升级不受第三方节奏牵制，与"核心不依赖平台、平台代码在能力包"
  的仓库约定一致。

宿主侧 Extension 模板（`Podfile` 里加 target，`Info.plist` 声明
`NSSupportsLiveActivities = YES`），SwiftUI 锁屏视图大致是：

```swift
// 两行歌词 + Text(timerInterval:) 驱动的进度条——进度条用系统计时器自走，
// Dart 侧只在换行/暂停时 update，锁屏刷新次数最少。
HStack { Text(state.line); Text(state.nextLine).opacity(0.6) }
ProgressView(timerInterval: state.lineRange, countsDown: false)
```

## 4. 需要补的数据字段

`DesktopLyricState` 目前只有歌词行与样式（样式字段对锁屏无意义，Activity 不消费）。
Live Activity 需要的最小新增：

| 字段 | 用途 |
| --- | --- |
| `trackTitle` / `artist` | 锁屏 Activity 的头部标识（Apple 风格模板必备） |
| `lineStart` / `lineEnd`（Duration 相对曲目） | 配合 `Text(timerInterval:)` 让进度在锁屏自走，Dart 不逐秒 update |
| `isPaused` 已有 | 暂停态显示与预算降频 |

这些都是控制器手上已有的信息（歌词行时间轴 + 播放状态），纯增字段，不破坏现有
`MethodChannel` 消费者。

## 5. 更新节奏与预算（关键设计点）

- **只在换行 / 播放暂停恢复 / 换曲目时 `update()`**，不做逐秒推进——进度条交给
  `Text(timerInterval:)`/`ProgressView(timerInterval:)` 用系统计时器自走。这样锁屏
  Activity 的刷新频率 = 换行频率（一首歌几十次），远低于系统对 Activity 的任何限流。
- 暂停时把 `isPaused` 与当前行一次性 update，恢复播放同理；App 若被系统杀掉，
  Activity 走 stale 展示（显示最后一行），音乐场景不可达。
- 灵动岛紧凑视图只放"当前行截断 + 进度点"，expanded 视图放双行——同为宿主 Extension 内容。

## 6. 工作量与风险

| 项 | 量 | 备注 |
| --- | --- | --- |
| `LiveActivityLyricTransport`（Dart） | 小 | 与 MethodChannel 实现同构 |
| iOS 插件三方法（Swift） | 小 | 纯 ActivityKit 调用，无 UI |
| `DesktopLyricState` 增字段 | 小 | 纯增量 |
| 宿主 Widget Extension | 中 | 每个宿主一次；media_core 提供 Swift 模板 |
| 风险：宿主忘建 Extension | 低 | `request` 会抛错 → transport 如实报 false 并落 Noop |
| 风险：iOS 版本门槛 | 低 | 16.0/16.1 以下 `isSupported()` 返回 false，走既有 Noop |

明确不做的：远程推送续更（App 被杀后续更歌词没有音乐场景意义）、锁屏 UI 的主题定制 API
（那是宿主 Extension 的 SwiftUI 代码，Dart 够不着）。

## 7. 落地顺序建议

1. `DesktopLyricState` 增字段 + 控制器填充（纯 Dart，可先测）。
2. iOS 插件三方法 + `LiveActivityLyricTransport` + `isSupported()` 平台门槛。
3. example/music 页加一个 iOS 开关；仓库附 `example/ios` 的 Widget Extension 模板。
4. 文档：本文件补一段宿主接入步骤（Info.plist、Podfile target、模板代码）。
