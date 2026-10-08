# media_core_ijk_player

[ijkplayer](https://pub.dev/packages/ijkplayer) 一系（引擎是 `flv_lzc` 分支）的 media_core 后端适配器：FLV / H.265 这条线上移动端的老将，实现完整、可用。

## 定位

`FlvLzcPlayerAdapter` 继承 `PlayerAdapterBase`、实现 `PlayerVideo`，把 `FijkPlayer` 接到 [media_core](../media_core) 的契约上：`onInitialize` / `onOpen` / `onPlay` / `onPause` / `onStop` / `onSeek` / `onSetVolume` / `onSetRate` / `onSetAudioOnly` / `onApplyEngineOptions` / `onCaptureFrame` / `onClose` / `onDispose`，画面侧 `build()` / `available` / `setVideoFit()`（`attach()` / `detach()` 是空操作，`FijkView` 自己管 surface 生命周期）。能力由 `FlvLzcPlayerAdapter.defaultCapabilities` 一份声明（选择器与引擎升级只读它），协议与容器清单来自核心的 `IjkFormats`。

后端 id 是 `kIjkPlayerBackendId = 'ijk'`，`registration()` 默认 priority 90——低于 media_kit（100）、高于 fvp 与 better_player（80）。

**引擎依赖是一条 git 分支**：`flv_lzc`（`https://github.com/liuchuancong/flv_lzc.git`，钉在 commit `162030d642857109048a8e6858d502b8d73c754a`），不是 pub.dev 上的包。pub.dev 不接受带 git 依赖的发布，所以在它变成 hosted 版本（或本包改成 `publish_to: none`）之前，这个包只能按路径 / git 依赖分发。

## 用法

```dart
import 'package:media_core/media_core.dart';
import 'package:media_core_ijk_player/media_core_ijk_player.dart';

final kernel = PlayerKernel()
  ..registerBackend(FlvLzcPlayerAdapterFactory(
    // 引擎自己的词汇：(domain, key, value) 三元组，每次 open 前逐条写下去。
    options: const <EngineOption>[
      EngineOption('reconnect', '10', domain: 'format'),
      EngineOption('timeout', '5000000', domain: 'format'),
      EngineOption('mediacodec', true, domain: 'player'),
    ],
  ).registration());

final handle = await kernel.create(
  source: PlayerSource(id: SourceId('room'), uri: Uri.parse('https://example.com/live.flv')),
  preferredBackend: kIjkPlayerBackendId,
);
```

`domain` 映射到 `FijkOption` 的分类：`host` / `format` / `codec` / `sws` / `swr` / `player`（默认 `player`）；认不出的 domain 回答 `EngineOptionOutcome.unsupported`，不猜。适配器不发明任何选项，也不内置重连/超时/代理预设——那三个是这条线最常要的，但它们属于调用方的 `options`，逃生口就是原样透传任何本类没包装的 ijk 选项。运行时 `applyEngineOptions` 一律回答 `stagedForNextOpen`：ijk 接受写入，但多数选项要等下一次 `prepareAsync` 才被消费，要立刻生效请在核心侧 `handle.rebuildEngine()`。

只有两样是适配器替你做掉的：

- **请求头**：`PlayerSource.headers` 经 `FijkHelper.sourceHeaderOptions` 翻成 ijk 的 `format` 选项——CRLF 结尾的 `headers` 串，`user-agent` 单独提到 `user_agent`（ijk 分开处理它）。校验走框架唯一那条规则（`HttpHeaderSanitizer`）：发不出原样的头在这里被拒，而不是悄悄改写。
- **快照开关**：IJKPlayer 不设 `enable-snapshot`（host 分类）就不给截图，而截图请求来得远比写选项晚，所以每次 open 都强制写一次——这是 `supportsScreenshot: true` 的前提。

## 几处照实的限制

- **直播源拒绝 seek**：`onSeek` 对 live 抛 `UnsupportedError`。FLV 直播没有可回退的时间窗，ijk 被要求 seek 时会卡住或报错；静默 no-op 只会留下"进度条动了、流没动"。变速同样对 live 直接返回。
- **截图只有 JPEG**：引擎的原生快照是 JPEG；请求 PNG 时适配器返回 `null`，核心退回抓渲染面（那条路真的产 PNG）。声明能力不等于"任何格式"。
- **纯音频**靠 `player` 分类的 `disable-vid` 真关解码器，不是把画面藏起来；`available` 在 audio-only、已释放、以及 `idle` / `error` 状态下都是 false，免得 `MediaPlayerView` 在任何源存在之前挂出一块空纹理。
- 状态与时长/尺寸从 `_player.value` 做差值得到，位置走 `onCurrentPosUpdate`；`started` 每 tick 都会触发，所以 playing/completed 有闩；同一句错误也去重，免得错误态每次回调都重报一次。

## 日志：引擎的日志跟着宿主走

ijkplayer 的日志**不经过** `MediaCoreLog`：状态迁移一行、每个播放器创建/释放打印一整块（logcat 里是 `IJKMEDIA` 标签），插件自己的 Dart 层每次调用再补一行（`[fijk] ...`）。一个房间一个播放器的宿主，一场下来就是几百行——看起来像"这个适配器日志太多"，而适配器本体一行都没打。

引擎自带开关，本包把它接在日志枢纽上（`FijkHelper.syncLogLevel()`，在 `onInitialize` 里、第一次碰播放器之前调用一次）：

| `MediaCoreLog.level` | 引擎级别（fijk） | 效果 |
| --- | --- | --- |
| `nothing`（默认） | `Silent` | logcat 里没有引擎日志 |
| `error` / `critical` | `Error` / `Fatal` | 只留错误 |
| `info` / `warning` | `Info` / `Warn` | 常规 |
| `debug` / `trace` | `Debug` / `Verbose` | 引擎的完整输出，排查 IJK 问题时用 |

映射是单向的（枢纽越安静，引擎越安静），所以**枢纽依旧是唯一权威**：宿主不需要为引擎再学一个开关，量级换算由插件自己做（`level / 100` 后夹到 0..8，再交给 ijk 的 `setLogLevel`）。级别按进程缓存，换房间不会重复下发。

## 平台支持

只有 **Android 与 iOS**：`flv_lzc` 带的是这两边的 ijkplayer 原生库。桌面与 Web 请用 [media_core_media_kit](../media_core_media_kit/README.md) 或 [media_core_fvp](../media_core_fvp/README.md)；四个后端可以并存，核心按协议、格式、直播能力与优先级打分选。

本包 `lib/media_core_ijk_player.dart` 顺带再导出 `package:flv_lzc/fijkplayer.dart`（`FijkPlayer`、`FijkView`、`FijkState`、`FijkValue`、`FijkOption`、`FijkLog`），宿主只依赖本适配器就能拿到引擎类型；`FijkHelper` 另有两个通用件：`formatDuration` 与 `getIjkBoxFit`（把 `BoxFit` 翻成 `FijkFit`）。

## 相关文档

- 核心与契约：[../media_core/README.md](../media_core/README.md)（`PlayerAdapterCapabilities` 在 `lib/adapter/`）
- 同层适配器：[media_core_media_kit](../media_core_media_kit/README.md) · [media_core_fvp](../media_core_fvp/README.md) · [media_core_better_player](../media_core_better_player/README.md)
- 日志枢纽：[../media_core_logging/README.md](../media_core_logging/README.md)
- 仓库总览：[../../README.md](../../README.md)
