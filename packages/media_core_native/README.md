# media_core_native

> media_core 的原生平台插件（联邦式 plugin）：提供主包所需的原生能力入口。

## 定位

[media_core](../media_core) 主包刻意与平台解耦（见 `platform`、`audio` 等模块的接口定义）。本包承担各平台的原生实现，已实现第一项：

- ✅ **平台能力查询**（`platform` 模块的 `PlatformProvider` 接口）——见下方"能力探针"
- ✅ **后台执行**（`BackgroundExecution`）——长时间任务（录制、下载）在应用退到后台时不被冻结/睡眠
- ⏳ 音频焦点 / 音频会话（`audio` 模块的 `AudioFocus` / `AudioSession` 接口）
- ⏳ 呈现适配（系统级 PiP 的**帧投递层**：`SystemPip` 在 Android 由 `floating` 插件覆盖，iOS 要 `AVSampleBufferDisplayLayer` 才能进系统 PiP，探针已能如实回答平台是否支持）

## 后台执行

录制或下载是"用户让它做，然后就不看了"的活。没有这层保护，屏幕一关，进程几秒内就被冻结或杀掉，FFmpeg 退出码说不了任何原因。

### 走统一契约（新代码用这条）

`media_core` 的 `background` 模块定义了任务申请后台能力的契约，这个包提供它的平台后端：任务只声明"我是谁、我在做什么、要不要 CPU 醒着"，服务、唤醒锁、通知都归运行时决定。

```dart
final result = await NativeBackgroundRuntime.shared.acquire(
  const BackgroundRequest(
    id: 'recording/主播8891',
    kind: BackgroundExecutionKind.recording,
    title: '正在录制',
    description: '00:12:34 · 312 MB',
    progress: BackgroundJobProgress.indeterminate(),
  ),
);

if (result case BackgroundAcquireSuccess(:final lease)) {
  try {
    await startTheJob();
  } finally {
    await lease.release();
  }
} else {
  // (result as BackgroundAcquireRejected).reason：平台不支持 / 服务被拒 / 权限没有 / 请求本身不合法
}
```

`NativeBackgroundRuntime.shared` 是全进程共用的那一个登记表（第一次用到时创建；宿主自己装过 `BackgroundRuntimes.current` 就用宿主的）。它把请求翻译成下面这套通道调用，Java 侧的多任务聚合与唤醒锁引用计数**原样保留**——重复计数的问题在登记层解决，而不是在服务层再记一遍。

录制与 `media_core_download`（`keepAlive`）都走这条路。媒体**播放**不走：它有自己的服务与主人（`media_core_mediasession` 的 `audio_service`），也不是 `BackgroundExecutionKind` 的一员。

### 直接用通道

```dart
final session = await BackgroundExecution.acquire(
  notification: BackgroundNotification(
    title: '正在录制',
    text: '$roomName · 00:12:34',
    kind: BackgroundJobKind.record,
    icon: 'ic_stat_record',                       // 宿主 res/drawable|mipmap 里的名字，可省
    progress: const BackgroundProgress.indeterminate(),
  ),
);

try {
  await startTheJob();
} finally {
  await session?.release();   // 会话对象就是"谁来负责收回"的答案
}
```

| 平台 | 会话做了什么 |
| --- | --- |
| Android | 起一个前台服务（API 34+ 声明为 `dataSync`）并显示通知（点击回到应用），同时持有 `PARTIAL_WAKE_LOCK`，屏幕熄灭后 CPU 继续跑 |
| iOS | 申请后台任务断言：买到的是"过渡窗口"（约 30 秒）而不是无限时间——长录制需要应用自己声明 `audio` 后台模式，这个库替不了 |
| macOS | `beginActivity(.idleSystemSleepDisabled)`：系统不睡，屏幕可以关 |
| Windows | `SetThreadExecutionState(ES_SYSTEM_REQUIRED)`：系统不睡（**不**阻止息屏） |
| Linux | ⏳ 未实现（logind `Inhibit`），`acquire` 返回 null |

### 通知能设什么

`BackgroundNotification` 就是宿主的输入口，库不替它编词：

| 字段 | 说明 |
| --- | --- |
| `title` / `text` | 两行文字，宿主自己的语言与内容（房间名、节目名、文件名） |
| `kind` | 任务类型，决定没给 `icon` 时用哪个内置字形（record / download / task） |
| `icon` | 宿主自己 `res/drawable` 或 `res/mipmap` 里的名字（与 `MediaSessionConfig.playIcon` 同一套约定，`@drawable/` 前缀也接受）；找不到名字就退回内置字形，不会留下一条没有图标的通知 |
| `progress` | `BackgroundProgress.determinate(current, total)` 画进度条，`BackgroundProgress.indeterminate()` 画转圈 —— 直播录制没有总量，转圈才是诚实的形状 |

跑起来以后用 `session.update(description.copyWith(text: ...))` 替换描述：录制就是每秒推一次"已录时长 · 已写字节"。**一个功能的那条通知只描述该功能里最新启动的会话**，早启动的任务更新自己的描述不会把通知从后来的任务手里抢走；它结束时通知回到还在跑的那个，正文的 `+N` 数的是**同一功能**剩下的任务。

按钮 / 操作（需要一条回调进 Dart 的通道）是**故意不可配**的；通知渠道按功能一个（`media_core.recording` / `media_core.download` / `media_core.background`），用户想只静音下载、留着录制做得到。媒体**播放**通知是另一套面（`media_core_mediasession` 的 `MediaSessionConfig`），不是这里的任何一条线。

会话是**按 id 计数**的，而**一个功能一个前台服务**：`RecordingForegroundService` / `DownloadForegroundService` / `GenericForegroundService`（共同基类 `JobForegroundService`），各自的通知 id（`0x4D52` / `0x4D44` / `0x4D43`）、各自的渠道、各自的唤醒锁 tag。会话句柄的高 16 位是功能、低 16 位是序号，所以 `update` / `release` 回到的一定是它原来那个服务，不需要第二份"谁持有哪个 id"的登记表。释放只退自己 —— 把服务停掉就等于把还在跑的任务暴露给系统，所以唤醒锁只在最后一个需要它的会话消失时才放开，且那只影响本功能。释放是幂等的。

`POST_NOTIFICATIONS`（Android 13+）由本包**声明但不申请**：什么时候问用户是宿主决定，`media_core_notify` 的 `requestPermission()` 是这个问题唯一的入口。早先版本在第一次 `acquire` 里通过当前 Activity 弹窗，那等于让一个后台恢复的下载把系统对话框顶在用户脸上并等答案。**拒绝不等于失败** —— 前台服务与唤醒锁照旧生效，只是用户看不到那条通知，这是用户的选择，不是让录制失败的 reason。平台连服务都不肯起（受限后台启动、清单缺失）时才返回 null。

Android 侧需要的清单条目（`FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC` / `FOREGROUND_SERVICE_SPECIAL_USE` / `WAKE_LOCK` / `POST_NOTIFICATIONS` 与那三个 `<service>`）**已在本插件的清单里声明**，会合并进应用——普通的 `<service>` 可以来自库清单。**audio_service 不在这一条里**：它自己的库清单是空的，媒体播放的 `AudioService`（`mediaPlayback`）和 `MediaButtonReceiver` 必须写在应用的清单里，缺一项后台播放就没有服务可起、控制条也无从显示（`example/` 里已经写了）。

Android 15 给 `dataSync` 前台服务设了**每天 6 小时**的额度，所以下载和普通任务留在 `dataSync`；直播录制没有可用期限，它声明 `specialUse`（清单里带 `android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE` 的理由说明，上架时同样的话还要在商店里再写一遍）。额度用完系统会停掉**那个**服务并在 `onTimeout` 里干净收尾，不会让进程因为不响应被杀，也不会连带摘掉别的功能的保护。

### 状态回流（`media_core_native/background_status`）

保活是平台持有的，所以"它被收走了"这件事只有平台知道。服务通过一条 EventChannel 把 `{id, status}` 送回 Dart，`id` 就是 `acquire` 给你的那个句柄：

| 上报 | 什么时候 | 含义 |
| --- | --- | --- |
| `protectionLost` | `onTimeout`（额度用完） | 豁免和唤醒锁没了，**任务还在跑**。不是 `stopped`（没人 release 过），也不是失败 |
| `stopped` | 服务被销毁而登记表里还留着会话 | 这条会话不再持有任何东西 |
| `degraded` | 会话启动时缺 `POST_NOTIFICATIONS` | 锁与豁免都在，只是那条通知用户看不见 |

Dart 侧整个进程只订阅一次通道，再按句柄分发给各条 lease，所以一条下载的消息不会被读成录制的消息。认不出的状态名一律丢弃，而不是猜成 `stopped`：插件可能比读它的 Dart 新，猜错就等于让一个还在跑的任务在纸面上失去保护。进程被整体杀掉时没有任何一路事件能送出（Dart 也一起没了），这是平台的限制，不是这里的漏洞。

## 能力探针

主包知道**后端**支持什么，只有平台知道**设备**能做什么：这台机器是把 HEVC 交给硬解单元还是交给四个慢核、还剩多少内存留给解码管线、系统有没有画中画。探针只问一次，把答案交给核心：

```dart
final provider = await NativePlatformProvider.load();
kernel.attachPlatformProvider(provider);

// 之后每个 session 与每个适配器都带着真实答案：
handle.session.context.platform;   // 能力标志（reported: true）
// 适配器上下文：device（核数/内存/ABI）+ codecs（逐编解码器硬解与分辨率上限）
```

消费点（不是"定义了没人用"）：

| 位置 | 用到的答案 |
| --- | --- |
| `PlayerKernel.create` → `SessionContext.platform` | 能力标志不再写死为 `const PlatformCapabilities()` |
| `PlayerKernel.create` → `PlayerAdapterContext` | `platform` / `device` / `codecs` 随播放器下传 |
| `MediaKitPlayerAdapter._applyDecoderPolicy` | `MpvDecodePolicy`：设备没有该编解码器的硬解时直接软解，不再浪费一次注定失败的硬解尝试 |
| `LiveBufferPolicy` | 低内存设备的前向/后向缓冲字节上限 |

### 契约

通道方法只有一个：`probe`。上报 map 最多四段，**每一段都可以缺**：

```text
{
  "info":         { type, name, version, buildNumber, architecture, deviceModel, isEmulator },
  "capabilities": { hardwareDecode, softwareDecode, pictureInPicture, backgroundPlayback, … },
  "device":       { cpuCores, totalRamMb, lowRamDevice, supports64BitAbi },
  "codecs":       { video: { h264: { hardware, maxWidth, maxHeight, maxFrameRate }, hevc: {…} } }
}
```

**缺失字段、缺失整段、调用失败，意思都是"未知"，绝不是"不支持"。** 这条规则是这一层存在的全部意义：一个因为"没人问过"就以为设备不能硬解的后端，会拒绝这台机器明明能播的流。所以：

- `PlatformCodecCapabilities.canDecodeInHardware` 返回 `null` 表示未知（调用方应让引擎自己试），`false` 才是"平台说了没有"；
- 探针失败时 `NativePlatformProvider.isReady == false`，`PlatformDeviceProfile.isLowEnd == false`（未知设备不做降级）；
- Windows 能枚举出硬解 MFT 却拿不到分辨率上限，上限记 0（未知），于是"有硬解"这个事实仍然生效。

## 代码结构

| 文件 | 说明 |
| --- | --- |
| `lib/media_core_native.dart` | 对外门面：`NativePlatformProvider`、`PlatformProbeReport`、平台接口 |
| `lib/src/platform/native_platform_provider.dart` | `PlatformProvider` 实现：探针一次、缓存、`refresh()` |
| `lib/src/platform/platform_probe_report.dart` | 通道载荷 → 核心词汇（`PlatformCapabilities` / `PlatformDeviceProfile` / `PlatformCodecCapabilities` / `PlatformInfo`） |
| `lib/src/platform/media_core_native_platform.dart` | 平台接口（token 校验的 `instance`，便于替换实现） |
| `lib/src/platform/method_channel_media_core_native.dart` | MethodChannel (`media_core_native`) 默认实现 |
| `android/**/MediaCoreNativePlugin.java` | `MediaCodecList` / `ActivityManager` / `DisplayManager` / `Build` |
| `windows/platform_probe.cc` | `MFTEnumEx` 硬解枚举 / `DXGI` 外接屏 / `GlobalMemoryStatusEx` / `RtlGetVersion` |
| `linux/platform_probe.cc` | `/proc/meminfo`、`/sys/class/drm`、`/dev/dri`、`/etc/os-release`（纯 std C++，无 GLib） |
| `ios/Classes/MediaCoreNativePlugin.swift` | `VideoToolbox` / `AVPictureInPictureController` / `ProcessInfo` / `uname` |
| `macos/Classes/MediaCoreNativePlugin.swift` | `VideoToolbox` / `NSProcessInfo` / `NSScreen` / `sysctl` |

## 平台支持

| 平台 | 状态 |
| --- | --- |
| Android | ✅ 编解码矩阵（含分辨率/帧率上限）、内存与 low-RAM、PiP 与外接屏、后台播放（看清单声明）、机型与模拟器识别 |
| Windows | ✅ 硬解 MFT 枚举（h264/hevc/vp9/av1）、多屏、内存与核数、真实系统版本 |
| iOS | ✅ `VTIsHardwareDecodeSupported` 的 h264/hevc、系统 PiP 支持、后台播放（看 `UIBackgroundModes`）、内存/核数/机型/模拟器 |
| macOS | ✅ 同上（`VideoToolbox` + `sysctl` + `NSScreen`），多屏 |
| Linux | ✅ `/proc/meminfo`、`/dev/dri` 渲染节点、DRM connector 外接屏、发行版识别 |

两处刻意的"不回答"，都是同一原则的推论：

- **Linux 不上报编解码矩阵。** 要真答"这台机器有没有 H.264 硬解"需要 libva 或 V4L2 M2M；链接 libva 会让插件在没装它的机器上编译不过，而仅凭渲染节点推断"逐编解码器"支持，正是这层要防的能力谎报。所以平台级答案走 `capabilities.hardwareDecode`（有渲染节点即有 GPU 驱动），逐编解码器保持未知，引擎行为不变。
- **iOS 的系统 PiP 只报"平台支持"。** `AVPictureInPictureController.isPictureInPictureSupported()` 是平台事实，但真正进入系统 PiP 还需要一条帧投递通路（`AVSampleBufferDisplayLayer`），本包目前不提供；因此 `media_core_pip` 的 `SystemPip` 在 iOS 上仍然回答 `unavailable`，而不是报了个能力却进不去。

尚未接入的平台上 `load()` 不会报错：探针失败即"未知"，播放照常。

## Example

见 [example/](example/)：一个"能力报告"界面，把探针在这台设备上的原样答案打出来。原生侧只能在真机上验证，这块屏幕就是验证面。

## 相关文档

- 主包架构：`packages/media_core/media_core_architecture_guide.md`
- 平台抽象：`packages/media_core/lib/platform/README.md`
- 音频抽象：`packages/media_core/lib/audio/README.md`
