# media_core_media_activity

iOS 锁屏歌词 / 灵动岛的 media_core 能力包（ActivityKit Live Activities +
MPNowPlayingInfoCenter + MPRemoteCommandCenter）。

分工原则（spec §3、§10、§20.1）：

- **Flutter 是数据源**：歌词解析、当前行计算、播放状态全部在 Dart 侧，插件只搬运
- **Swift 不持有播放状态**：锁屏/耳机指令全部经 Pigeon 路回宿主的播放层
- **事件驱动**：只在换歌 / 换行 / 播放状态翻转 / seek 时推送；锁屏自己按
  `rate × Δt` 走时间，绝不推进度定时器（spec §8.1）
- **一切降级**：设备不支持、用户关闭、创建被拒，都表现为「功能关闭」，不影响播放
  （spec §13.3）

iOS pod 拆成两个 subspec：

- `Shared`：`MediaActivityAttributes` 数据契约（无 Flutter 依赖）——宿主的
  Widget Extension 只链接它：`pod 'media_core_media_activity/Shared'`
- `Plugin`（默认）：Pigeon 桥接 + ActivityKit 生命周期 + Now Playing + 遥控指令，
  由 Flutter 插件机制装进 Runner

## 使用

Dart 侧入口是 `MediaActivityCoordinator`（宿主喂数据）和
`MediaActivityController`（唯一写者），命令回传实现 `MediaActivityCommandSink`。
完整接入步骤（含 Widget Extension 的 Xcode 集成）见
[example/README.md](example/README.md)。

## 宿主 App 需要做的

1. `Info.plist` 打开 `NSSupportsLiveActivities`（iOS ≥ 16.1 生效）
2. Runner 与 Widget Extension 都加 App Group `group.media_core.media_activity`
3. 写一个 Widget Extension：`pod 'media_core_media_activity/Shared'`，用
   `MediaActivityAttributes` 渲染锁屏 / 灵动岛视图
