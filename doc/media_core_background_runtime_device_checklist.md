# media_core 后台运行时：真机验证清单（阶段 5）

> 配套文档：`media_core_background_runtime_architecture.md`（§14.7 记的就是这里没做完的事）。
> 本清单只写"怎么做、看什么、看到就说明什么"。Dart 单测已经守住的部分（登记表路由、句柄寻址、
> 投影按功能分行、未知名丢弃）不在这里重复。

## 0. 准备

| 项 | 值 |
| --- | --- |
| 演示包名 | `com.example.example`（`example/android/app/build.gradle.kts:19`） |
| 最低 / 目标 SDK | minSdk 26（ffmpeg_kit 决定）、targetSdk 随 Flutter |
| 设备矩阵 | Android 13（API 33）、Android 14（API 34，服务类型强校验）、Android 15（API 35，`dataSync` 额度）、Android TV 一台、iOS 一台、Windows / macOS / Linux 各一 |
| 装包 | `cd example && flutter run --debug`（或 `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`） |

**已知前置缺口（会挡住第 10 节）**：`example` 目前不依赖 `media_core_notify`，所以桌面平台的"每功能一条线"
与"作业结果通知"在演示应用里没有任何调用点——不是功能坏了，是没人装。要么先接（另一次改动），要么第 10 节
改用一个临时 `MediaCoreNotify.enable()` 的分支包来验。

另外：本插件 Java 侧**不打日志**。所以下面的证据一律来自 `dumpsys` 与 demo 的输出文本；若某步判不下来，
先补一条 debug 级日志再看，不要靠猜（这是可选改动，不在本清单内）。

用到的 demo（应用内按名字找）：`background-execution`（两条作业会话 + 进度）、
`media-session-ownership`（媒体面所有权）、`recording`、`download`、页面 `player` / `music`。

---

## 1. 三个功能各自的通知身份

跑 `background-execution`（它会依次取录制会话、再取下载会话），然后：

```bash
adb shell dumpsys notification --noredact | sed -n '/NotificationRecord.*com.example.example/,+8p'
adb shell dumpsys power | grep -i "media_core:"
adb shell dumpsys activity services com.example.example | grep -E "ServiceRecord|foregroundServiceType|isForeground"
```

期望：

- **两条**通知（不是 `+1` 合并成一条）：`media_core.recording` 与 `media_core.download` 各一条，
  标题分别是录制和下载的正文。
- 通知 id：录制 `19794`（`0x4D52`）、下载 `19780`（`0x4D44`）、未命名任务 `19779`（`0x4D43`）。
- 唤醒锁：`media_core:recording`、`media_core:download` 各自存在（`demo` 的两个会话都要求 wake lock）。
- `dumpsys activity services` 里是**两个不同的服务进程组件**：
  `RecordingForegroundService` / `DownloadForegroundService`，各自 `foregroundServiceType`
  （`specialUse` / `dataSync`）。

看到一条合并线、或两个功能共用一个 `ServiceRecord` ⇒ 合并/路由又退回到单服务模型，回去查
`JobForegroundService.Feature` 与 `BackgroundExecutionDelegate.ownerOf`。

## 2. 渠道在系统设置里各自可静音

设置 → 应用 → example → 通知，应看到 **录制进行中 / 下载进行中 / 后台任务** 三个渠道（外加
`media_core_notify` 的两个，若已装）。把"下载进行中"静音，重跑第 1 节：下载那条不再出现，
录制那条照旧。静音一个不影响另一个，就是这一轮要的用户可见结果。

## 3. 权限矩阵（不弹对话框，也照样保活）

```bash
adb shell pm revoke com.example.example android.permission.POST_NOTIFICATIONS
```

跑 `download` 会话，观察：

1. **没有任何系统对话框**弹出来（本插件不申请权限，`MediaCoreNotify.requestPermission()` 是唯一入口）。
2. 通知不可见，但 `dumpsys power | grep media_core:` 仍有唤醒锁，`dumpsys activity services` 仍显示前台服务。
3. 会话状态被上报为 `degraded`：`background-execution` 的输出里那条会话不再是"running"。
   这是 `degraded` 的真实生产者——服务在跑，只是用户看不见那行。

再 `adb shell pm grant com.example.example android.permission.POST_NOTIFICATIONS`，重新取一次会话：通知出现。
两次的差别只应该是"看不看得见"，任何一次让任务失败都是错的（拒绝通知不等于失败）。

## 4. Android 14+ 的服务类型强校验

正常包应当已经通过（库清单声明了 `FOREGROUND_SERVICE_SPECIAL_USE` / `_DATA_SYNC`）。**故意做坏**一次，
验证"被系统拒绝"这条路如实回报而不是崩：在 `example/android/app/src/main/AndroidManifest.xml` 临时加

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"
    tools:node="remove" />
```

跑录制的 acquire：期望 demo 打印 `acquire -> null` / refusal `foregroundStartRejected`，**进程不崩**，
任务继续跑（只是没保护）。然后删掉这段临时声明再跑一次，恢复正常。

同理可用 appops 造"后台不能起服务"：

```bash
adb shell cmd appops set com.example.example RUN_FOREGROUND_SERVICES_FROM_BACKGROUND ignore
```

从后台触发一次 acquire，期望同样是 refusal 而不是 `ForegroundServiceStartNotAllowedException` 崩溃。
（验完记得 `set ... allow` 复位。）

## 5. 三条线互不影响（本轮的核心断言）

同时跑：`music`/`player` 页面播放（媒体面）+ `background-execution`（录制会话 + 下载会话）。期望**三条**通知：

| 线 | 来源 | 渠道 | 停止后应发生 |
| --- | --- | --- | --- |
| 媒体控制条 | `media_core_mediasession`（audio_service） | audio_service 自己的渠道 | 只有播放停了；两条作业线不动 |
| 录制 | `RecordingForegroundService` | `media_core.recording` | 只有录制线消失 |
| 下载 | `DownloadForegroundService` | `media_core.download` | 只有下载线消失 |

逐个停止（先停下载，再停录制，最后停播放），每步后用第 1 节的三条 `dumpsys` 命令确认：**剩下的两条线
文本与 id 完全没变**。任何一次"停了 A，B 的文字变了/没了"都是这一轮要消掉的耦合复发。

`adb shell dumpsys media_session | sed -n '1,30p'` 里应只有一个活跃会话，且它排在通知/锁屏上；
`media-session-ownership` demo 会打印 `activeSessionId` 的每一次变化（接管→被点名的是上一任→
陈旧收走与陈旧改写都无效→交还）。

## 6. 超时与状态回流的时序

- `degraded`：见第 3 节，随时可验。
- `stopped`（服务销毁时还登记着会话）：`adb shell am kill com.example.example` 会连 Dart 一起杀，
  **不能**用来验这条；可行的做法是让宿主在会话仍持有时正常 `stopSelf`（当前只有最后一个会话释放会走到，
  此时登记表已空），所以这条主要靠单测覆盖，真机上属于"验不到"的一项，照实记录即可。
- `protectionLost`（`dataSync` 额度用完）：**adb 无法提前触发**（Android 没有公开的强制/缩短开关）。
  可行的验法是在 Android 15 设备上让一个下载会话连续跑过 6 小时（可以反复重启下载以累积），到点后查：
  1. `dumpsys activity services` 里 `DownloadForegroundService` 已不在前台；
  2. **录制那条线不受影响**（这是拆分前后的关键差别：以前它会被同一个服务一起停掉）；
  3. demo 输出里该会话状态变成 `protectionLost`，并且 `activeSessionId` 意义上的那一行随之消失；
  4. 录制继续，唤醒锁 `media_core:recording` 仍在。

  如果只想验"事件能到达 Dart"这一段，单测已经用 `BackgroundExecution.debugPublishReport` 覆盖了；
  真机这一项验的是**Android 真的会调 `onTimeout`、以及它只停自己的服务**。

## 7. 息屏、doze 与省电

```bash
adb shell dumpsys deviceidle force-idle      # 进入 doze
# 等 2 分钟，观察录制是否继续写字节、下载进度是否推进
adb shell dumpsys deviceidle unforce
```

期望：息屏 + doze 下两条作业都继续推进（`dumpsys power | grep media_core:` 的锁仍在，
`mLastWakeLock` 统计增长）。若录制停在某个字节数，先确认 `BackgroundRequest.requiresCpuWakeLock`
有没有被宿主传成 false（`recording/<前缀>` 会话应当是 true）。

顺带查白名单效应：设置 → 电池 → example 设为"无限制"，重复本步骤，结果不应变（变差说明保护实际
来自白名单而不是我们的锁，这一条要记下来）。

## 8. 任务滑走与进程重建

1. 播放中把应用从最近任务滑掉：`MediaSessionConfig.androidStopOnRemoveTask` 默认 `false` ⇒
   播控仍在，声音继续；改成 `true` 重装一次 ⇒ 滑走即停，且媒体通知消失。两个值都要跑。
2. 作业服务是 `START_NOT_STICKY`：滑走/杀掉后**不应**看到系统在几分钟内自己把录制拉起来
   （拉起来会往同一个目录写第二段，这不是我们要的行为）。
3. 被系统重建进程后，Dart 侧登记表是空的（进程级状态），下一次 acquire 一切正常——
   验的是"没有僵尸会话占着渠道"。

## 9. iOS 边界

期望与文档一致：`acquire` 返回的是一个**转场窗口**级别的会话（约 30 秒），不是无限时间。

- 息屏 60 秒后录制应当停/被冻结：这就是 iOS 的诚实答案，**不是** bug；要长时间录制必须声明
  `audio` 后台模式，而那是宿主应用的能力，不是本包的。
- 没有前台服务概念，所以 `BackgroundCapability.persistentNotification` 不该被授权；
  Dart 侧的每条功能线（第 10 节）就是 iOS 上用户唯一看得见的东西。
- `degraded`/`protectionLost` 在 iOS 上没有生产者，验不到就记"不适用"。

## 10. 桌面三平台（需要 notify 已接线，见第 0 节）

| 平台 | 期望 |
| --- | --- |
| Windows | 无 FGS；`ForegroundJobs` 画每功能一条线（`media_core_recording` / `media_core_download` / `media_core_jobs`）；SMTC 显示播放；作业结果通知走 `media_core_results` |
| macOS | 同上；通知落在"录制进行中/下载进行中"各自的渠道；睡眠断言在 `pmset -g assertions` 里可见 |
| Linux | 后台执行**未实现**：`acquire` 如实回答 `unsupportedPlatform`，任务照跑；Dart 侧线仍应画出（`platformCapabilities` 为空 ⇒ `drawsLine` 为真） |

关键断言：停掉下载只收走下载那条线（`clearRunningLine(id: 3)`），录制那条（`id: 2`）文本不变；
两个功能的并发计数只数自己那一个（"还有 N 个任务"）。

## 11. Android TV / 遥控器

`media-session-ownership` 与播控在 TV 上必须可用：方向键能进入 demo 列表并运行，播放控制条在
遥控器"媒体键"下响应；作业通知在 TV 的收件箱里存在（TV 的通知 UI 与手机不同，线不能消失）。
`appops`/权限相关步骤在 TV 上若入口不同，按等价的设置项走并在记录里注明。

## 12. 记录格式

每个设备一行，一次运行一列，写**观察到的**而不是"应该"：

| 设备 / 系统版本 | 步骤 | 结果 | 证据（dumpsys 摘要 / demo 文本） | 结论 |
| --- | --- | --- | --- | --- |
| Pixel 系 / Android 15 | 1 三个功能身份 | ✅/❌/N-A | `...` | |

## 13. 已知不算失败

- 第 6 节的 `stopped`：真机上没有可控触发点，单测覆盖即可，记 N-A。
- iOS 上录制超过转场窗口被冻结：平台限制，文档 §5 已写；要长录必须宿主声明 `audio` 后台模式。
- 进程被整体杀掉时收不到任何状态事件（Dart 一起没了）：平台限制，不是漏洞。
- Linux 上 `acquire` 返回 `unsupportedPlatform`：未实现如实回答，比伪装成功好。
- `example` 未装 `media_core_notify` 导致的"看不到桌面线"：接线问题，第 0 节已标。
