# media_core_media_activity 示例：锁屏歌词 + 灵动岛（Widget Extension 集成）

演示宿主 App 如何接入 `media_core_media_activity`，并用一个 **Widget Extension**
在 iOS 锁屏 / 灵动岛上渲染 Live Activity 歌词。

架构分工（spec §3、§10）：

| 层 | 谁负责 | 在哪 |
| --- | --- | --- |
| 数据 | Flutter：歌词解析、当前行计算、播放状态 | `lib/demo_session.dart`（宿主侧参考实现） |
| 桥接 | 插件：ActivityKit 生命周期、Now Playing、遥控指令 | 插件 `ios/Classes/Plugin/`（默认 subspec，宿主不直接碰） |
| 像素 | 宿主的 Widget Extension：SwiftUI 视图 | `ios/WidgetExtension/` |
| 契约 | 双方共读的 `MediaActivityAttributes` | 插件 `ios/Classes/Shared/`（`Shared` subspec，无 Flutter 依赖） |

## 目录结构

```
example/
├── lib/
│   ├── main.dart                 # 演示页：能力探测、播放卡片、事件按钮、指令日志
│   └── demo_session.dart         # 模拟播放会话：事件驱动驱动 coordinator + 指令回传
├── test/
│   └── demo_session_test.dart    # 9 个测试，跑在任何平台（用 fake platform）
└── ios/
    ├── Podfile                   # Runner + MediaActivityWidgetExtension 两个 target
    ├── Runner/Info.plist         # 已加 NSSupportsLiveActivities
    ├── Runner/Runner.entitlements        # App Group 参考文件
    └── WidgetExtension/          # Xcode 建 target 后放入的 4 个文件
        ├── MediaActivityWidgetBundle.swift
        ├── MediaActivityLiveActivityWidget.swift   # 锁屏视图 + 灵动岛视图
        ├── Info.plist
        └── MediaActivityWidgetExtension.entitlements
```

## 前置条件

- macOS + Xcode 15+（Widget Extension target 只能在 Xcode 里建）
- CocoaPods（`gem install cocoapods`）
- iOS 16.1+ 真机或模拟器；灵动岛需要 iPhone 14 Pro 及以上的机型/模拟器
- 本包只声明 iOS 平台；在 Windows/Linux 上只能跑 Dart 层（analyze / test）

## 集成步骤（宿主 App 照做即可）

### 1. 依赖

```yaml
dependencies:
  media_core_media_activity:
    path: <插件路径>
```

### 2. 建示例/宿主的 iOS 工程

```bash
cd example
flutter pub get        # workspace 内在仓库根执行即可
open ios/Runner.xcworkspace
```

### 3. 新建 Widget Extension target

Xcode 里 **File > New > Target > Widget Extension**：

- 名称必须叫 **`MediaActivityWidgetExtension`**（与 `ios/Podfile` 里的 target 名一致）
- 取消勾选 *Include Configuration App Intent*（本示例不需要交互 intent）
- Uncheck *Live Activity* 也可以——我们用自己写的视图；勾了也无妨，把 Xcode 生成的
  swift 模板文件删掉即可

然后把 `ios/WidgetExtension/` 下的 4 个文件拖进这个 target（删掉 Xcode 生成的同名
模板文件）：

- `MediaActivityWidgetBundle.swift`
- `MediaActivityWidgetExtension.entitlements`
- `Info.plist`
- `MediaActivityLiveActivityWidget.swift`

在 target 的 **Build Settings** 里确认 `INFOPLIST_FILE` 指向这份 `Info.plist`，
`CODE_SIGN_ENTITLEMENTS` 指向这份 entitlements。

### 4. 打开 Live Activities 能力

`Runner/Info.plist` 已经写好（自己集成时照抄）：

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

### 5. App Group（Runner 和 Extension 都要加）

两个 target 各自 **Signing & Capabilities > + Capability > App Groups**，加
`group.media_core.media_activity`（与插件 `Shared/MediaActivityAttributes.swift`
里的 `appGroupId` 常量一致）。仓库里给了两份参考 entitlements 文件，保证 id 不漂移。

### 6. 装 pods 并运行

```bash
cd example/ios
pod install            # Runner 装 Flutter 插件 pods；Extension 装 Shared pod
cd ..
flutter run            # 或在 Xcode 里直接选 MediaActivityWidgetExtension + Runner
```

`flutter run` 前 Xcode 若提示 Xcode 13+ 的多 target 签名问题，在两个 target 的
Signing 里选同一个 Team。

### 7. 验收

1. App 里点「开始播放」→ 锁屏出现 Live Activity（歌词 + 曲名）和 Now Playing 卡
2. 点「下一句」→ 锁屏歌词换行；两次事件之间锁屏按 `rate × Δt` 自己走时间，不推进度
3. 暂停 → 歌词引擎停，锁屏只剩最后一行（spec §9.4）
4. 「换一首」→ 旧 activity 被替换（`sessionId` 变了）
5. **灵动岛**（14 Pro+ 模拟器/真机）：紧凑态显示曲名进度，长按展开歌词
6. 在 **Now Playing 卡**（不是 Live Activity）按播放/暂停/拖进度 → App 内
   「锁屏指令回传」列表出现对应指令 —— 这是 `MPRemoteCommandCenter` 路回 Dart 的
   通路；Live Activity 自身不带按钮（交互按钮要 iOS 17 的 ActivityKit，spec §13.2）

## 宿主侧怎么写（`demo_session.dart` 是参考实现）

```dart
final controller = MediaActivityController(platform: PlatformMediaActivity.resolve());
final coordinator = MediaActivityCoordinator(controller: controller, playerId: 'demo');
controller.commandSink = this;          // 锁屏指令路由回宿主

// 换歌/开播：一次事件，插件负责 end 旧 + start 新
await coordinator.onTrackChanged(metadata, state);

// 歌词推进：只在边界上调用，绝不定时推进度
await coordinator.onLyricChanged(currentLyric: '…', nextLyric: '…');

// 暂停/继续/seek
await coordinator.onPlaybackChanged(isPlaying: false, positionMs: 0, playbackRate: 0);
await coordinator.onSeekCompleted(positionMs: 30000);

// 结束
await coordinator.onSessionEnded();
```

非 iOS 平台全部自动降级为 no-op（能力探测返回「不支持」），宿主代码不需要判平台。

## 常见问题

- **锁屏什么都没出现**：检查系统设置里的 Live Activities 开关、`NSSupportsLiveActivities`、
  iOS ≥ 16.1；插件 `getCapabilities()` 会返回具体原因（`activitiesEnabled` 为 false
  = 用户关了系统开关）
- **Extension 编译报 Flutter 相关错误**：Podfile 里 Extension target 只能链接
  `media_core_media_activity/Shared`，链接了整个 pod 会把 Flutter 依赖带进来
- **artwork 显示默认图形**：示例没有写封面文件。真集成时宿主把封面按内容 hash 写进
  App Group 的 `MediaActivity/Artwork/` 目录（文件名即 `artworkKey`），扩展用
  `MediaActivityAttributes.artworkURL(forKey:)` 读取；不要走 base64（4KB 限制，spec §12）
- **日志里 `activity_already_active`**：同一个 `sessionId` 重复 start 被控制器拒绝了，
  属宿主逻辑 bug（spec §9.2）
