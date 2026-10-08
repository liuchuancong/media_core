# media_core_cast_dlna

`media_core` 的 DLNA/UPnP 投屏后端：SSDP 发现、设备描述解析、SOAP `AVTransport` / `RenderingControl` 命令与 DIDL-Lite 载荷，全部藏在那份与协议无关的 `MediaCastBackend` 契约后面。

## 定位

核心的投屏分层是：**控制器、设备模型与 UI 状态归 `media_core`，某一个协议的 socket 与报文编码归后端包**。本包就是 DLNA 那一份——`DlnaCastBackend` 实现 `MediaCastBackend`，`id` 为 `'dlna'`，与 `CastDevice.backendId` 对齐。宿主面向 `CastController` 写投屏，不需要知道对面是 SSDP 还是别的什么；加一个协议或去掉一个协议，控制器都不会察觉。

DLNA 的模型一段话能说清：SSDP 用 `LOCATION` 通告设备，那个地址上有一份描述文档，文档列出各服务的控制 URL，之后每个动作就是一次 SOAP POST。没有会话，也没有鉴权。分层之后必须由后端负责的是这几件事：

- **通告的新鲜度。** `SsdpDiscovery` 按 `searchInterval`（默认 12 秒）重发 M-SEARCH，尽力加入组播组（接口不支持时静默跳过——单播回包仍然收得到），并为每台设备按它自带的 `CACHE-CONTROL: max-age`（缺失或畸形按 30 秒）挂一个到期定时器。设备直接消失是不会发 BYEBYE 的（Wi-Fi 不会通知你），所以到期也算离开：`BYEBYE` 与内部生成的 `EXPIRED` 都会让后端发 `DeviceLost`，选择列表里因此不会留着一台已经睡了十分钟的电视。
- **两台身份证不一致。** 规范说 USN 的根等于 UDN，多数设备遵守，也有机器一边补服务后缀一边改 uuid 格式。后端记住 USN→UDN 的映射，专门为了这一类设备：否则 BYEBYE 带着一个没人认识的身份到达，死电视会一直留在列表里直到缓存过期。
- **描述取不到就不上报。** 首次通告时取一次描述文档（已知的与正在取的都不重复拉，免得刷穿局域网）。读不出 UDN 或没有 `AVTransport` 服务就抛 `FormatException`，被记成 `CastFault` 而不是塞进列表——会广播但不服务 HTTP 的电视同样接受不了投屏，列出它只是给选择器加一行死的。
- **失败要说成失败。** 投一个设备自己取不到的 URL（token 门 + 只有 app 能发的请求头）必然失败在设备侧。命令失败一律 `CastException`（不返回可能被忽略的错误码），并把 SOAP fault 解成 `SoapFault`（`errorCode` / `errorDescription`）带在 cause 上。`position()` 反过来：设备不再应答时返回 `CastPosition.unknown()` 而不是抛——进度环该变灰，UI 不该因为一台刚离网的电视崩掉。
- **不假装会事件推送。** DLNA 的播放状态本该走 GENA 订阅，而 Flutter 应用不该为此起一个 HTTP 服务器，所以 `eventSubURL` 只解析不订阅；播放进度由核心的 `CastController` 按 `positionInterval`（默认 2 秒）轮询 `GetPositionInfo` 拿。
- **没有网络也能测。** 三处缝隙都是注入点：`SsdpSource`（脚本化的消息流）、`DescriptionFetcher`（直接给 XML）、`SoapPoster`（查表回 SOAP 信封）。默认的 `dart:io` 实现由 `dispose()` 关掉自己建的两个 `HttpClient` 连接池；宿主传进来的函数带走自己的生命周期，本包不越权关。

## 用法

```dart
final backend = DlnaCastBackend();               // 默认 SSDP 发现 + dart:io HTTP
final cast = CastController(backend: backend);   // 核心给的那一层，ChangeNotifier
await backend.startDiscovery();                  // 幂等

cast.addListener(() => paint(cast.devices, cast.transportState, cast.position));

final tv = cast.devices.first;                   // DeviceFound 之后才会出现在里面
await cast.cast(tv, CastMedia(
  url: directPlayableUrl,                        // 设备必须自己能取到
  title: '第四集',
  mimeType: 'video/mp4',
  objectClass: 'video.item',
  artworkUrl: Uri.parse(coverUrl),
));
await cast.pause();
await cast.seek(const Duration(minutes: 3));     // REL_TIME 单位的 Seek
await cast.setVolume(40);                        // 走 RenderingControl；设备没这服务就抛 CastException
await cast.stopCasting();                        // 设备留在 devices，只结束会话
await backend.dispose();                         // 关发现与 socket
```

协议层也能单独用——自建控制器，或者只想知道网段里有什么：

```dart
final discovery = SsdpDiscovery(searchInterval: const Duration(seconds: 30));
discovery.rawDatagrams.listen((d) => dump(d.text, d.from));  // 排查"设备从错误的网卡应答"
final message = SsdpMessage.tryParse(payload);  // 认不出的包返回 null：一个坏包不该打断发现

final description = DlnaDeviceDescription.parse(xml, location: Uri.parse(message.location!));
final didl = DidlLite.build(media);             // http-get:{mime}:{DLNA.ORG_PN=…}，MIME 未知时退回 *
```

`Soap` 是无状态编码器（`SetAVTransportURI` / `Play` / `Pause` / `Stop` / `Seek` / `GetPositionInfo` / `GetTransportInfo` / `GetVolume` / `SetVolume`）：参数名严格按 SCCD 写死（`InstanceID` 少一个字母就是每台真机上的 500 故障），`Content-Length` 按 UTF-8 字节数算（中文标题走 DIDL 时按 UTF-16 长度会把信封截断），响应按 local name 查（各固件的命名空间前缀不一样，本地名才一致）。设备描述里的相对控制 URL 一律锚到根解析，因为 `ctrl-avtransport` 这种不带斜杠的写法对着 `/description.xml` 解析会算错兄弟路径。

## 平台支持

| 平台 | 状态 |
| --- | --- |
| Android / iOS / macOS / Windows / Linux | ✅ 纯 Dart：`RawDatagramSocket`（UDP 组播）+ `HttpClient`，无平台代码、无方法通道 |
| Web | ❌ 依赖 `dart:io`，浏览器里跑不了 |
| 局域网权限 | ⏳ 不在本包：本包没有平台层，因此拿不到 Android 的多播锁、也不写 iOS 的本地网络用途声明。这些必须由宿主配置；缺了它们的表现是收不到 `NOTIFY` 通告（主动 `M-SEARCH` 的单播回包通常仍能到） |

发现流量只落在同一网段的标准组播组 `239.255.255.250:1900`，搜索目标默认是 `urn:schemas-upnp-org:device:MediaRenderer:1`（自己建 `SsdpDiscovery` 时 `start` 可传别的 ST）。本包不上传设备信息、也不持久化任何设备身份：`CastDevice` 只活在内存里，`dispose()` 即清空。响应体一律限量读取（`maxCastResponseBodyBytes`，1 MiB），描述位置只接受 `http`/`https`——URL 来自局域网里任何一台应答者的报文，不能当成可信输入。

## 相关文档

- 契约与控制器：[../media_core](../media_core)（`lib/casting/`：`MediaCastBackend`、`CastController`、`CastDevice`、`CastMedia`、`CastPosition`）
- 界面层（投屏入口与弹层归宿主）：[../media_core_ui](../media_core_ui)
- 仓库总览：[../../README.md](../../README.md)
