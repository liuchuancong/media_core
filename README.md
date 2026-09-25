# media_core

跨平台可复用的 Flutter 播放器核心。39 个自包含模块 + 一个把它们全部串起来的编排层（kernel）。

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

## Workspace 布局

```text
packages/
  media_core/               核心（本包）
  media_core_media_kit/     media_kit 适配
  media_core_better_player/  video_player 适配
  media_core_ijk_player/    ijk (niuma_player) 适配
  media_core_native/        原生适配
examples/example/           示例 App
```
