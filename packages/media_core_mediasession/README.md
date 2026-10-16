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

**出去的方向有节奏**：位置每 1 秒最多发一次，其余（playing / speed / duration / 控件表）一到就发。播放器的 transport 流一秒能报很多次（引擎侧未收敛前是每帧一次），而每一次 publishState 到 Android 就是一次通知重建——锁屏那条进度条本身大约一秒才重画一次，多发的都是电池和热量。往回跳（seek、换歌的零位置）算"换了条时间线"，不等窗口，立刻发。

## 用法：应用启动时挂一次，之后全自动

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 一行：之后创建的每个内核都自动带上它，每次播放都自动交给它。
  await MediaSessionBootstrap.enable();

  runApp(const MyApp());
}
```

内核本来就负责"谁是活跃播放器、什么时候切换"——所以一个进程一个驱动就够了，宿主不必逐个播放器写 `attachAudio`。想要封面就用 `enable(artUriResolver: ...)`（视频源通常只有 URL 和标题）；想让某个内核不上系统面（设置页预览、诊断播放器）就传 `KernelOptions(autoAttachAudio: false)`；内核在 `enable()` 之前就创建了，用 `MediaSessionBootstrap.attachTo(kernel)` 补挂。

**为什么是一个进程一个驱动**：平台只有一条媒体通知——一个 `AudioService` handler、一个 SMTC 会话、一个 MPRIS 名字；两个驱动会互相抢，而且 `AudioService.init` 第二次调用在 debug 会直接断言失败。所以由 bootstrap 独占那一个实例。

**为什么必须显式开启**：发通知、起前台服务是应用级决定（要清单条目、图标资源、Android 13+ 还要运行时权限）。库在背后替宿主做这件事，轻则意外，重则在那份清单缺失时直接崩。所以不调 `enable()` 就什么都不发生；调了之后才是自动的。

### 手动路径（不用 bootstrap 时）

```dart
final kernel = PlayerKernel()..registerBackend(MediaKitAdapterFactory().registration());

final session = MediaSessionDriver(config: const MediaSessionConfig.video());
await session.initialize();      // 一次，早点调用（runApp 之前也行）
kernel.attachAudio(session);     // 内核把"当前活跃播放器"交给它

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

## 这块控制条归谁

系统只有一个媒体面：一条通知、一个锁屏条目、一个 SMTC/MPRIS 会话。所以本包把它当成**有主人的资源**，而不是谁都能写的共享变量：

| 谁 | 怎么拿 | 能不能改写别人的 |
| --- | --- | --- |
| 内核的活动播放器（`kernel.attachAudio` 那条路） | `setActive(handle)` → 会话 id 是 `player/<handle id>` | 只能拿，不能盖 |
| 音乐模块的 `MusicBackgroundBinding` | 同上（它通过 `setActive`） | 只释放自己拿到的那条 |
| 宿主自己（多画面、直播墙、任何"这一路现在归我显示"的判断） | `await MediaSessionSurfaces.activate(sessionId: 'cell-2', title: '房间2')` | 拿到时会告诉它上一任是谁 |

`MediaSessionSurfaces` 是宿主的门（`activate` / `updateMetadata` / `deactivate` / `activeSessionId`），不用先拿到 driver 实例；`MediaSessionSurfaces.driver` 就是 `MediaSessionBootstrap.current`，需要 `setActive(handle)` 之类更底层的东西时从那里走。它存在的理由很小但很实在：`MediaSessionBootstrap.current` 是 null 的时候，宿主很容易把"没启用媒体面"读成"接管成功了"，而这条门会明确回答 `notEnabled`。

四种拒绝各有各的动作：`notEnabled`（先 `MediaSessionBootstrap.enable()`）、`notInitialized`（握手还在跑，等一下）、`surfaceUnavailable`（这平台根本没有媒体面，别等）、`disposed`（还在调用一个已经扔掉的驱动）。

之后：`updateMetadata` 与 `deactivate` **只对当前主人有效**。这就是多画面切换里那个真出过的 bug——旧播放器停止时的迟到回调会把刚接手那一格的标题与控件一起清掉；现在它被忽略，因为会话 id 不匹配。

`driver.activeSessionId` 就是"现在谁在上面"的唯一答案。`dispose()` 交还整个面（`releaseSurface`）而不是把它停在 idle 上——一个没有主人的会话留在锁屏上，就是还在播放的假象。

**什么时候该 activate**：真实播放状态（transport 在播或在缓冲）、音频焦点、平台允许后台播放。这三样都不满足时不该拿面，尤其**不该**因为"某个 surface 已经 ready"就顺手 activate：面的存在不是系统在为你保活的理由。

## 通知上的相位

`MediaSessionState.phase` 是把播放器真实状态说给平台听的那一半：

| 相位 | 平台看到 | 什么时候 |
| --- | --- | --- |
| `idle` | 没有会话 | 开了源还没播、或已经停止 |
| `loading` | 正在取资源 | 引擎进入装载态 |
| `buffering` | 转圈 | 播放中途缺数据（此时 `playing` 仍是 true） |
| `ready` | 可以继续 | 数据够了，播或暂停都算 |
| `completed` | 到头了 | 播头 ≥ 时长且不在播 |

以前这里只有 `ready`：卡住的流显示成"可用但没播"，停掉的显示成"就绪"，而控制条正是用户决定继续等还是走开的地方。相位变化**不**受那一秒位置节流——用户等的那件事必须现在到。

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
