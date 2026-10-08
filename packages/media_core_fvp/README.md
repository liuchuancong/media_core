# media_core_fvp

以 [fvp](https://pub.dev/packages/fvp)（libmdk）为引擎的 media_core 后端适配器：一条**当前 FFmpeg + 平台硬解优先**的解码通路，用来救默认引擎播不动的源。

## 定位

`FvpPlayerAdapter` 继承 `PlayerAdapterBase`、实现 `PlayerVideo`，把 mdk 接到 [media_core](../media_core) 的契约上。libmdk 自带较新的 FFmpeg（4.0–7.1 / master），优先使用平台硬解（MediaCodec、VideoToolbox、D3D11、VAAPI），FFmpeg 与 dav1d 作为软解退路。它读得下老引擎会丢的流——最典型的就是 `codec id 12` 的传统 HEVC FLV，media_kit 的 libmpv 对这种流只有声音没有画面。所以本包是"这个房间在默认引擎失败之后还得播"时该注册的那一个。

引擎来源是 pub.dev 的 `fvp: ^0.38.1`，**没有** vendor 精简副本：桌面构建会自己解析它的原生依赖。后端 id 是 `kFvpPlayerBackendId = 'fvp'`，`registration()` 默认 priority 80。

## 用法

```dart
import 'package:media_core/media_core.dart';
import 'package:media_core_fvp/media_core_fvp.dart';

final kernel = PlayerKernel()
  ..registerBackend(const FvpAdapterFactory().registration());          // 与 media_kit 并存，按能力与优先级选
  // 也可以直接进注册表 / 工厂：registerFvpRegistry(registry)、registerFvpFactory(factory)

final handle = await kernel.create(
  source: PlayerSource(id: SourceId('room'), uri: Uri.parse('https://example.com/live.flv')),
  config: const PlayerConfig(autoPlay: true),
  preferredBackend: kFvpPlayerBackendId,
);
```

配置就是构造参数，全是引擎自己的词汇：

```dart
FvpAdapterFactory(
  // 原生 mdk 属性，创建引擎时逐条写入（代理、白名单之类的决定权在调用方）。
  properties: const {'avio.http_proxy': 'http://127.0.0.1:7897'},
  // 默认 ['FFmpeg', 'dav1d']。传 null 与不传不等价：不传才会落到这份默认表。
  videoDecoders: const <String>['FFmpeg', 'dav1d'],
  audioBackends: null,                                    // null 保留 mdk 自己的默认后端顺序
  videoConfig: const FvpVideoConfig(maxWidth: 1920, maxHeight: 1080, fit: BoxFit.contain),
);

// 运行时：videoDecoders / audioDecoders / audioBackends 三个键有专门通道，其余按属性写。
await handle.applyEngineOptions([const EngineOption('videoDecoders', ['FFmpeg'])]);
```

`FvpVideoConfig` 里的 `maxWidth` / `maxHeight` 是给渲染目标设上限：4K 源塞进 1080p 界面时，不封顶就会分配一块全分辨率 RGBA 纹理，把弱 GPU 的电视推进 GPU 合成。`fitMaxSize` 决定这个上限是保比例内接还是逐轴夹紧；`tunnel: true` 把帧直接交给平台 surface，此时 libmdk 的 GL 渲染器被跳过，尺寸上限与滤镜都不再生效。

画面由适配器自己持有 Flutter `Texture`：`FvpVideoView(adapter: ...)` 是参考实现，它读 `textureListenable` / `sizeListenable` / `fitListenable` 再调 `adapter.buildSurface(...)`；widget 树属于宿主时就用这三个 listenable 自己拼。`mediaInfo` 暴露引擎报的流与编码信息。

## 引擎语义（照实说）

- **一个源一个引擎**。libmdk 每个 player 只在创建时定一次渲染目标尺寸，之后改不了，所以每次 `open` 都新建一个 mdk player 并释放上一个；不要把 `mdk.Player` 跨源持有。
- **位置、时长、缓冲、音量都靠采样**。libmdk 不把这些做成流，适配器在源打开期间每 500ms 轮询一次。直播看门狗因此能按位置判停滞——但**没有**解码帧回调，`supportsVideoFrameProgress` 恒为 `false`，看门狗不能为这个引擎装帧停滞定时器，否则健康的流会被反复拆掉重开。
- **失败是响的**。`prepare()` 返回负值、或 `MediaStatus.invalid`，都在 open 窗口内报成引擎失败（`PlayerErrorCode.backendOpenFailed`），核心据此换线路或换后端，而不是留下一段"只有声音的成功播放"。
- **几何拿不到会重试一次**。`textureSize` 有 10 秒上限；直播卡住时 libmdk 会以 null 完成它并且不再回头，此时适配器对当前 URL 重新 `prepare()` 一次，第二次仍为 null 就接受现实（没有画面，音频照播）。创建纹理失败（`updateTexture` 返回负值）按引擎错误上报。
- **纯音频**：`setActiveTracks(MediaType.video, [])` 关掉视频轨并释放纹理，每次 open 重新施加。`setAudioOutputSuppressed(true)` 只把音量压到 0、不动存储的音量值，用于引擎切换的空档。
- **请求头**写进 `avio.headers`（CRLF 行），名字或值里带 `\r\n:` 的头会被丢掉——宁可少一条头，也不让人借头名注入一行。
- 明确不做的：抓帧（`supportsScreenshot: false`，截图走渲染面抓取那条路）、轨道与字幕选择、滤镜、hwdec 信息、缓冲比例、循环、播放列表、元数据、系统 PiP，复合源声明 `CompositeSupport.none`（单 URL FFmpeg 解封装，没有外部音轨侧信道；libmdk 自带的 dash demuxer 是否在这份构建里可用未在设备上验证，所以不吹）。

## 平台支持

跟随 fvp 声明的平台：Android、iOS、macOS、Windows、Linux。Web 不在其列表内。移动端与桌面的硬解路径由 libmdk 自己选（MediaCodec / VideoToolbox / D3D11 / VAAPI），`supportsHardwareDecoder` 说的是 mdk 有这个能力，不是这块设备一定用上了。

## 相关文档

- 核心与契约：[../media_core/README.md](../media_core/README.md)
- 默认引擎（以及它为什么需要这一个）：[../media_core_media_kit/README.md](../media_core_media_kit/README.md)
- 同层适配器：[media_core_ijk_player](../media_core_ijk_player/README.md) · [media_core_better_player](../media_core_better_player/README.md)
- 需要代理或重写清单时的输入管线：`packages/media_core_ingest`
- 仓库总览：[../../README.md](../../README.md)
