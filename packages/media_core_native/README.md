# media_core_native

> media_core 的原生平台插件（联邦式 plugin）：提供主包所需的原生能力入口。

## 定位

[media_core](../media_core) 主包刻意与平台解耦（见 `platform`、`audio` 等模块的接口定义）。本包承担各平台的原生实现，已实现第一项：

- ✅ **平台能力查询**（`platform` 模块的 `PlatformProvider` 接口）——见下方"能力探针"
- ⏳ 音频焦点 / 音频会话（`audio` 模块的 `AudioFocus` / `AudioSession` 接口）
- ⏳ 呈现适配（系统级 PiP，`media_core_pip` 的 `SystemPip` 接口；iOS 需要 `AVPictureInPictureController`）

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
| `windows/platform_probe.cc` | `MFTEnumEx` 硬解枚举 / `DXGI` HDR 与外接屏 / `GlobalMemoryStatusEx` / `RtlGetVersion` |

## 平台支持

| 平台 | 状态 |
| --- | --- |
| Android | ✅ 编解码矩阵（含分辨率/帧率上限）、内存与 low-RAM、PiP 与外接屏、机型与模拟器识别 |
| Windows | ✅ 硬解 MFT 枚举（h264/hevc/vp9/av1）、多屏、内存与核数、真实系统版本 |
| iOS / macOS | ⏳ `VideoToolbox`（`VTIsHardwareDecodeSupported`）与系统 PiP 待实现 |
| Linux | ⏳ `libva` / `/dev/dri` 与 `/proc/meminfo` 待实现 |

尚未实现的平台上 `load()` 不会报错：探针失败即"未知"，播放照常。

## Example

见 [example/](example/)：一个"能力报告"界面，把探针在这台设备上的原样答案打出来。原生侧只能在真机上验证，这块屏幕就是验证面。

## 相关文档

- 主包架构：`packages/media_core/media_core_architecture_guide.md`
- 平台抽象：`packages/media_core/lib/platform/README.md`
- 音频抽象：`packages/media_core/lib/audio/README.md`
