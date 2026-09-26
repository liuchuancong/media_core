# media_core_mediasession

> 把内核里的**任意**播放器接到系统的媒体面上：Android 通知、iOS 锁屏/控制中心、Windows SMTC、Linux MPRIS，外加音频焦点、打断处理与"拔耳机就暂停"。

## 为什么单独成包

这不是音频功能。视频播放器要的是同一份东西——同一条通知、同一个锁屏条目、同一套媒体键——差别只在装修（把上一首/下一首换成 ±10 秒、频道名不一样）。把它留在音乐模块里，视频宿主就为了一个通知被迫依赖整个音乐模块（音源、歌词、桌面歌词、下载、ffmpeg）。所以它在这里，`media_core_audio` 反而改为依赖本包。

```text
PlayerHandle.playbackStream ──▶ MediaSessionHandler ──▶ 通知 / SMTC / MPRIS
通知按钮 / 锁屏 / 媒体键     ──▶ MediaSessionHandler ──▶ PlayerHandle
音频焦点打断（来电、别的播放器） ──▶ 暂停 / 压低 / 恢复
拔耳机                      ──▶ 暂停
```

## 用法

```dart
final kernel = PlayerKernel()..registerBackend(MediaKitAdapterFactory().registration());

final session = MediaSessionDriver(config: const MediaSessionConfig.video());
await session.initialize();      // 一次，早点调用（runApp 之前也行）
kernel.attachAudio(session);     // 内核把"当前活跃播放器"交给它

// 视频源通常没有封面：告诉它去哪儿找
session.artUriResolver = (source) => thumbnailFor(source.uri);

final handle = await kernel.create(source: source, config: const PlayerConfig(autoPlay: true));
// 通知里现在有标题、播放/暂停、±10 秒、停止，按下去就是操作这个 handle。
```

不带内核也能用：`session.setActive(handle)`。`setActive` 在 `initialize` 之前调用是安全的——绑定会记住，等 handler 就绪后由 `refresh()` 补发布，不会出现"通知里空空如也"。

## 通知上有什么

`MediaSessionConfig.showControls` / `showSeekButtons` / `seekStep` 决定，规则是"有什么能力就显示什么控件"：

| 宿主 | 通知控件 |
| --- | --- |
| 单媒体（视频默认，`MediaSessionConfig.video()`） | 播放/暂停、**±seekStep**、停止 |
| 装了队列传输的宿主（音乐，见 `MusicBackgroundBinding`） | 上一首、播放/暂停、下一首、停止 |

`MediaAction.rewind` / `fastForward` 由平台按键给出，步长是**你的**决定，所以它在这里（`seekStep`，默认 10 秒）；换了步长记得配一套对应的图标——图标名必须存在于宿主的 `res/drawable`，缺图标时通知会一个控件都不显示，看起来像播放器坏了，而不是像少了个资源。

## 宿主自己必须声明的（库替不了应用）

- **Android**：`AudioServiceActivity`、`AudioService` 服务、`MediaButtonReceiver` 三个清单条目（`audio_service` 的硬性要求，因为应用自己的 Activity 被替换）；API 33+ 还要 `POST_NOTIFICATIONS`——`media_core_audio` 的 `AudioPermissionService` 正好提供这一个（`AudioPermission.notifications`），或用自己的权限插件。
- **iOS**：`Info.plist` 里的 `audio` 后台模式。没有它，应用一挂起锁屏条目就消失。
- **图标**：`MediaSessionConfig` 里那几组 drawable 名。

## 与 `media_core_audio` 的关系

`media_core_audio` 现在依赖本包，它的 `MediaCoreAudio` 是本包 `MediaSessionDriver` 的薄子类（历史名字），`AudioCapabilityConfig` / `MediaCoreAudioHandler` / `AudioHandlerState` / `AudioHandlerMediaItem` 是同一批类型的别名——音乐宿主不受影响，而两边只有一份实现。

## 平台支持

| 平台 | 系统面 |
| --- | --- |
| Android | 媒体通知（含控件、封面）、锁屏、媒体键；前台服务 |
| iOS | 锁屏 / 控制中心 Now Playing、媒体键 |
| Windows | SMTC（系统媒体传输控件、音量浮层） |
| Linux | MPRIS（D-Bus）：GNOME/KDE 媒体部件与媒体键 |
| macOS | 通过 audio_service 的 iOS 实现路径（锁屏条目可用） |
