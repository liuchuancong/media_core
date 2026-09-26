# media_core_recording_ffmpeg

用 FFmpeg（ffmpeg_kit_extended_flutter）把网络流录成**分段 MPEG-TS + CSV 清单**。

实现 [media_core](../media_core) 的 `RecordingBackend` 契约；"录什么"由宿主决定，"怎么排"由内核的
`RecordingManager` 决定，这里只负责：把源与配置翻成 FFmpeg 参数、持有进程、把进程结局映射成录制状态。

```dart
final backend = FfmpegRecordingBackend(outputDirectory: '/storage/recordings');
await backend.start(
  RecordingSource.network(url),
  const RecordingConfig(outputPath: '/storage/recordings'),
);
// …录制中…
final result = await backend.stop();     // 用户主动停止是"成功录制"
```

## 为什么是分段而不是一个文件

直播没有自然结尾。进程被杀、应用被系统回收时，一个正在增长的文件通常**播不了**——索引从来没写过。
分段各自可播，CSV 清单说明它们怎么接起来，所以最坏情况是"丢几秒"，而不是"丢几小时"。
退出码也不是成败判据：用户主动停止同样会得到 255，所以后端记录**意图**（stop / cancel）再据此汇报。

## 后台与休眠

录制是"用户让它做、然后就不看了"的活。没有下面这层，屏幕一关，Android 会在几秒内冻结进程，
录制以一个说明不了任何原因的 FFmpeg 退出码结束。默认开启（`FfmpegRecordConfig.keepAlive`）：

- **Android**：前台服务（API 34+ 声明 `dataSync`）+ 通知 + `PARTIAL_WAKE_LOCK`（屏幕熄灭后 CPU 继续跑）。
  清单条目由 `media_core_native` 的插件清单合并进应用，`POST_NOTIFICATIONS` 也由它在第一次取会话时自己弹窗申请（应用不需要写这一步）。
  用户拒了通知权限时，前台服务与唤醒锁照旧生效（只是通知不可见），录制**照常进行**；只有平台连服务都不肯起时才拿不到会话（`acquire` 返回 null），录制依然继续，只是没有保护 —— 不会因为一条通知失败而挂掉录制。
  通知长什么样是宿主决定的：`keepAliveTitle` 给标题（默认 "Recording"）、`keepAliveIcon` 给宿主 `res/drawable` 里的图标名（默认用内置的录制字形），正文是"文件前缀 · 已录时长 · 已写字节"，每秒刷新一次；进度是**转圈**而不是进度条 —— 直播录制没有总量，画一根百分比条只是假装。
- **macOS / Windows**：持有睡眠断言（系统不睡，屏幕可以关）。
- **iOS**：只买到过渡窗口（约 30 秒）。要长时间后台录制，需要应用在 `Info.plist` 声明 `audio` 后台模式——
  这是应用的决定，库替不了；声明后录制才能在后台持续。
- **Linux**：⏳ 未实现（logind `Inhibit`）。

释放是"随录制结束"的，且覆盖每条结束路径（stop / cancel / 自行退出 / dispose）——通知不会比它描述的任务活得更久。

## 宿主的清单检查表（Android）

| 项 | 谁声明 |
| --- | --- |
| `FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_DATA_SYNC`、`WAKE_LOCK`、`POST_NOTIFICATIONS`、`<service …foregroundServiceType="dataSync">` | `media_core_native` 的库清单（自动合并） |
| 运行时申请 `POST_NOTIFICATIONS`（API 33+） | `media_core_native`（第一次取会话时弹出；宿主也可自己先问，授权后不会重复弹） |
| **明文流**：`android:usesCleartextTraffic="true"` + `res/xml/network_security_config.xml` | 应用 |

最后一条是直播录制最常见的"在模拟器能录、真机不行"的原因：Android 9+ 默认禁止明文 HTTP，
而直播源大多是 `http://` 的 FLV/HLS。示例应用里有可直接抄的文件：
`examples/example/android/app/src/main/res/xml/network_security_config.xml`。
