# media_core_native_example

把平台探针在这台设备上的答案原样打出来的界面。

```bash
cd packages/media_core_native/example
flutter run            # 建议直接跑在真机上：探针问的是设备，不是模拟器
```

屏幕上的每一行都是探针跨通道带回来的原文，未经任何引擎解释：

- **Reported** — 哪些段真的来自平台（`reported` 标志）。全为 false 说明当前平台还没有实现，
  或者探针调用失败，此时播放照常，只是所有"设备能力"都是未知。
- **Platform** — 系统版本、机型、架构、是否模拟器（来自 `RtlGetVersion` / `Build`）。
- **Capabilities** — 画中画、后台播放、外接屏等系统特性。
- **Device** — 核数、内存、是否 low-RAM、是否 64 位设备，以及由这些推出的软解线程数。
- **Video codecs** — 每个编解码器是"硬件 / 仅软件 / 未上报"。**未上报读作未知，不是不支持。**
- **Questions a backend asks** — 后端真正会问的问题：某编解码器在 1080p / 4K 上能否硬解。
  值为 null 表示平台没有答案，引擎应当自己试。

右上角刷新按钮会重新探测（`NativePlatformProvider.refresh()`），用于确认系统设置改变后的答案。
