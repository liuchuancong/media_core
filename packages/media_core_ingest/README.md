# media_core_ingest

`media_core` 的可播放输入管线：判断上游源能否直接交给播放器，还是必须经过 manifest 重写或 FFmpeg remux；然后把处理后的 loopback URL 交回给 player。

## 定位

直播提供商给出的 HLS/FLV 源经常带有播放器无法直接处理的特征——manifest 子路径是裸名称、绝对路径、签名 URL 中途过期、container 是播放器 FFmpeg 解不了的 codec-id-12 HEVC FLV。没有统一层，每个宿主都会各自长出 relay。

本包做一件事：**把"要不要中转"和"怎么中转"收敛到一处**。

- `resolveIngestPlan(needs: {...})` → `IngestPlan`：声明式决策，不猜。
- `LoopbackIngestRelay`：HLS manifest 重写——把子路径全变成绝对 `http://127.0.0.1:<port>/<secret>/...` URL，代理 children upstream 并保持 headers / session cookies。
- `FfmpegIngestRelay`：FFmpeg remux 为 rolling loopback HLS tree，处理 container 不兼容和 URL 过期交换；宿主通过 `IngestFfmpegStarter` 注入自己的 FFmpeg 运行时。
- `classifyHlsManifest` / `HlsManifestKind`：对 manifest body 分类子 URL 形态，决定是否需要 rewrite。
- `HlsSourceQueryPolicy`：精确的 token query 传播，只在验证过 provider 契约后 opt-in。
- `HlsSessionCookies`：bounded, origin-pinned cookie 容器，供 relay 跟随 provider 的 Set-Cookie。

## 用法

```dart
// 1. 判断源需要哪种 ingest 策略。
final kind = classifyHlsManifest(manifestBody);
final needs = <IngestNeed>{};
if (kind.requiresRewrite) needs.add(IngestNeed.relativeChildren);
if (signedUrlExpires) needs.add(IngestNeed.expiringUrl);

final plan = resolveIngestPlan(needs: needs);

// 2. direct 路径：直接给播放器。
if (plan.isDirect) {
  player.open(Media(source.toString()));
}

// 3. manifest relay：重写后的 loopback URL。
else if (plan.strategy == IngestStrategy.manifestRelay) {
  final relay = await LoopbackIngestRelay.start(
    source: source,
    headers: {'Referer': referer},
    sessionCookies: true,
  );
  player.open(Media(relay.inputUri.toString()));
  // 播放结束后：await relay.close();
}

// 4. FFmpeg relay：remux 进 loopback HLS。
else if (plan.strategy == IngestStrategy.ffmpegRelay) {
  final relay = await FfmpegIngestRelay.start(
    source: source,
    startFfmpeg: hostFfmpegStarter,  // 宿主注入的 FFmpeg
    headers: {'Referer': referer},
  );
  player.open(Media(relay.inputUri.toString()));
}
```

## 设计约束

- **direct 是默认**：relay 要进程/端口/1-3 s 启动，只有声明了 `IngestNeed` 才切走。
- **FFmpeg 不在包依赖里**：宿主通过 `IngestFfmpegStarter` typedef 注入自己的 FFmpeg runtime（ffmpeg_kit / 自行打包），本包不会链第二份。
- **DASH merge**：`FfmpegIngestRelay.startDashMerge` 处理视频/音频分路 DASH（bilibili 等），stream-copy 合成一条 HLS tree。
- **security**：relay 只监听 loopback IPv4 + path secret；cookie jar 严格 pin origin，不跨 host 共享。

## 平台支持

| 平台 | 状态 |
| --- | --- |
| Android / iOS / macOS / Windows / Linux | ✅ Dart `HttpServer` on loopback，全平台可用 |
| Web | ❌ `dart:io` 不可用；Web 宿主需自行处理 CORS |

## 相关文档

- [media_core](../media_core) —— 主包 `PlayerSource`、`PlaybackPoolOrchestrator`
- [media_core_recording_ffmpeg](../media_core_recording_ffmpeg) —— 同样使用 FFmpeg 子进程的录制后端
- [项目总览](../../README.md)
