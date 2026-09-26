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

```dart
final session = await BackgroundExecution.acquire(title: '正在录制', text: roomName);
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

会话是**按 id 计数**的，所以两个任务（一个录制 + 一个下载）不会互相拆掉对方的保护；释放是幂等的，平台拒绝（例如 Android 13+ 没给 `POST_NOTIFICATIONS`）时返回 null —— 任务照跑，只是没有保护，而不是因为一条通知失败就挂掉录制。

Android 侧需要的清单条目（`FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC` / `WAKE_LOCK` / `POST_NOTIFICATIONS` 与那个 `<service>`）**已在本插件的清单里声明**，会合并进应用——服务声明可以来自库清单（`audio_service` 那种需要替换 Activity 的才不行）；只有 `POST_NOTIFICATIONS` 仍需应用在运行时申请（`media_core_audio` 的 `AudioPermissionService` 正好提供这一个）。

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
| `lib/src/native_platform_provider.dart` | `PlatformProvider` 实现：探针一次、缓存、`refresh()` |
| `lib/src/platform_probe_report.dart` | 通道载荷 → 核心词汇（`PlatformCapabilities` / `PlatformDeviceProfile` / `PlatformCodecCapabilities` / `PlatformInfo`） |
| `lib/src/media_core_native_platform.dart` | 平台接口（token 校验的 `instance`，便于替换实现） |
| `lib/src/method_channel_media_core_native.dart` | MethodChannel (`media_core_native`) 默认实现 |
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
