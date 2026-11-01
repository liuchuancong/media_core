# media_core_cast_dlna

`media_core` 生态中独立、完整的 DLNA / UPnP 投屏协议包：SSDP 发现、设备与服务描述解析、SOAP 控制与 UPnP 错误映射、辅助 mDNS 通道，外加一个把这一切藏进 `MediaCastBackend` 契约后面的适配器。

交付合规审计见 [DELIVERY.md](DELIVERY.md)（§33 十五条逐条核验 + §30 架构约束 grep 证据）。完整工程技术规范见 [TECHNICAL_DESIGN.md](TECHNICAL_DESIGN.md)——职责边界、分阶段实施（Phase 0～10）、验收标准与 AI 开发规范都以那份文档为准。当前代码覆盖 **Phase 0～9（含 §25 日志与诊断）的全部代码与测试项**：协议基础设施（SSDP、描述解析、SOAP）、发现管理、DLNA 媒体能力协商、HTTP 媒体服务器、投屏会话与播放控制、GENA 状态订阅（轮询保底）、RenderingControl 音量/静音、断线恢复（多设备会话隔离）、厂商兼容层、结构化日志与诊断快照，外加生命周期压力测试（Phase 10 的代码侧验收）。**待真机矩阵**（Android TV / 智能电视 / Windows / macOS / Linux）完成 §10 的实测项：长时间播放、断网恢复、按实测数据填充厂商 profile 后正式 Release。

## 定位

**本包只实现 DLNA / UPnP 协议。** Google Cast、AirPlay、Miracast、屏幕镜像、播放器 UI、直播站点解析、音视频解码都不在这里。它不做"简单封装 SSDP 搜索"，而是按规范分成三层：

```text
lib/src/
├── domain/            纯 Dart 模型：DlnaDevice / DlnaService / DlnaMedia /
│                      DlnaMediaResource / DlnaMediaCapability /
│                      DlnaPlaybackState / DlnaTransportState /
│                      DlnaConnectionState / ServiceType / MediaProtocolInfo /
│                      DlnaException 体系 / UpnpErrorCode / SoapTransport 契约。
│                      不依赖 Flutter、Bonsoir、Socket、具体 HTTP 实现。
├── application/       用例编排：DlnaDiscoveryManager（发现流水线）、
│                      DlnaSessionManager + DlnaSession（投屏会话：串行命令
│                      队列、自适应轮询监控、SCPd 能力预检）、DlnaMediaSelector
│                      （能力协商）、DlnaCapabilityResolver（GetProtocolInfo）、
│                      DlnaDeviceRegistry、DlnaClient（公共门面）、
│                      DlnaDiscoveryOptions。
├── infrastructure/    协议实现：ssdp/（SsdpClient 多目标 M-SEARCH + NOTIFY
│                      监听 + max-age 到期）、description/（设备描述与 SCPD
│                      解析、带安全约束的 HTTP 拉取）、control/soap/（信封构建、
│                      响应与 fault 解析、SoapClient 超时与错误映射、
│                      DidlMetadata DIDL 构建）、control/services/
│                      （AvTransportService 类型化动作）、discovery/bonsoir/
│                      （辅助 mDNS 通道）、media/http/（MediaHttpServer：
│                      Token 资源 + GET/HEAD/Range 流式投送）、network/
│                      （局域网地址选择）、compatibility/（
│                      DeviceCompatibilityProfile/Registry：厂商怪癖治理）。
├── adapter/           media_core 桥接：DlnaCastBackend（MediaCastBackend）
│                      与 DidlLite 载荷构建。
└── utils/             UPnP 时钟字符串编解码（DurationCodec）与 MIME 推断
                       （MimeType）。
```

DLNA 的模型一段话能说清：SSDP 用 `LOCATION` 通告设备，那个地址上有一份描述文档，文档列出各服务的控制 URL，之后每个动作就是一次 SOAP POST。没有会话，也没有鉴权——这正是本包要在协议层替宿主把住的几道关：

- **发现以 SSDP 为主通道。** `SsdpClient` 按周期对每个搜索目标（默认 `MediaRenderer:1` 与 `:2`）分批发 M-SEARCH，尽力加入组播组（不支持时静默跳过，单播回包仍收得到），监听 NOTIFY，并按每台设备自带的 `CACHE-CONTROL: max-age` 挂到期定时器——设备直接消失是不会发 BYEBYE 的，到期也算离开（内部合成 `EXPIRED`）。`ssdp:update` 触发描述重验证。
- **身份以 UDN 为准。** IP 不是标识（DHCP 会变、代理会共享），设备名更不是。USN 根与 UDN 不一致的设备由 USN→UDN 映射桥接，否则一台 BYEBYE 带着陌生身份到达，死电视会在列表里留到缓存过期。
- **描述解析按设备实际给的来。** `DeviceDescriptionParser` 按本地名匹配（各固件的命名空间前缀不一致）、支持 `URLBase` 与嵌套设备（渲染器 Hub 常把 AVTransport 挂在子设备上）、serviceId / SCPDURL / eventSubURL 全部解析，相对 URL 锚定源解析。`ServiceDescriptionParser` 解析 SCPD 的 action / argument / stateVariable——能力判断的依据是设备声明，不是规范里有没有这个动作。
- **描述取不到就不上报。** `DlnaDiscoveryManager` 每台设备只取一次描述（续订不重拉），并发取数有上限，失败的设备进入退避而不是每个缓存周期被锤一次；`requireAvTransport`（默认开）把纯媒体服务器静默挡在列表外。设备经 `devices` / `deviceAdded` / `deviceUpdated` / `deviceRemoved` / `errors` 流对外暴露，`DlnaDiscoveryState` 跟踪生命周期。
- **失败要说成失败，而且说清是哪种失败。** `SoapClient` 把超时、断连与设备拒绝映射成 `DlnaTimeoutException` / `DlnaNetworkException` / `DlnaUpnpException`（带 `UpnpErrorCode` 分类与可重试性）——701 是电视活着在拒绝，超时是没人应答，重试策略完全不同。适配层把 `DlnaException` 译成 `CastException` 带在 cause 上；`position()` 反过来：设备不再应答时返回 `CastPosition.unknown()` 而不是抛——进度环该变灰，UI 不该因为一台刚离网的电视崩掉。
- **Bonsoir 只是辅助通道。** `BonsoirDiscoveryChannel` 浏览 DNS-SD 服务类型（默认 `_mediarenderer._tcp`），把 mDNS 通告作为 `MDnsServiceHint` 提示流输出。mDNS 通告没有描述 LOCATION，永远不能独立成为可投屏设备；SSDP 主通道不因它存在而弱化。某个服务类型初始化失败不影响其它类型。
- **能力协商看设备声明，不看品牌。** `DlnaCapabilityResolver` 走 `ConnectionManager.GetProtocolInfo` 拿 Sink 列表，`MediaProtocolInfo` 解析四段结构与 `DLNA.ORG_PN/OP/CI` 参数；`DlnaMediaSelector` 按格式、DLNA profile、Range 支持评分选资源。设备说了不支持的格式，投送前就地拒绝（`DlnaUnsupportedMediaException`，带逐资源原因）；探测失败降级为"未知能力"，投送照常——设备说得少不等于播不了。
- **本地文件走媒体服务器，路径不出本机。** `MediaHttpServer` 用随机 Token 注册文件（`/{token}/{id}`，无目录列举、无路径参数、过期清扫），支持 HEAD、单段字节 Range、206/416、正确的 `Content-Range`，文件流式发送从不整体进内存。`DlnaCastBackend.setMedia` 检测本地文件后自动注册并把 LAN URL 发给电视；DIDL 的 `res` 行也用改写后的 URL——电视拿不到、也看不到本机路径。
- **事件推送优先，轮询保底。** `GenaCallbackServer` 在本机起一个 Token 路由的回调端点，`GenaSubscriber` 走 SUBSCRIBE/续订/退订管理订阅（半生命周期续订，连续三次续订失败即放弃并保持轮询）；`GenaMessageParser` 把 PropertySet 与 AVT `LastChange` 都摊平成变量表，设备推送的状态变化直接并入会话快照。回调按 SID 校验、SEQ 去重、响应体限量——局域网里收到的每一条 NOTIFY 都不是可信输入。订阅失败或到期不续，会话继续用轮询（§14.7），进度条只是变慢，不会断。
- **厂商怪癖收敛在兼容层，不污染协议代码。** `DeviceCompatibilityRegistry` 按"注册顺序即优先级"解析 `DeviceCompatibilityProfile`（匹配厂商/型号/设备类型），`InstanceID`、`SOAPACTION` 引号、Seek 单位、Play 速度、是否发 DIDL 全部由 profile 声明；标准设备走 `standard` profile（全是规范默认值，零配置），新增一个厂商 = 注册一个 profile，领域模型与协议层一行不动（§9）。profile 内容随真机测试数据填充。
- **诊断快照随手可取。** `DlnaClient.diagnostics()` 一次返回 §25.3 的快照：设备数、活动会话数、媒体服务器与发现状态、时间戳——调试面板或健康检查不用翻包内部。
- **日志贯通，默认静默。** 核心各层经纯 Dart 的 `DlnaLog` 发结构化事件（§25 的分类/分级：发现/SSDP/描述/SOAP/GENA/媒体选择/媒体服务器/播放/会话），默认 sink 丢弃、坏 sink 不影响投屏；`DlnaCastBackend` 构造时自动桥接到 media_core 的 `MediaCoreLog`（网络类归 network、播放/会话各归其类）。URL 一律先剥 query/fragment 再入日志——媒体服务器 Token 不进日志（§22.5）。
- **没有网络也能测。** 每一层都有注入缝隙：`SsdpSource`（脚本化消息流）、`DescriptionFetcher`（直接给 XML）、`SoapTransport`（查表回信封）、`MDnsDiscoverySession`（脚本化 Bonsoir 事件）。默认 `dart:io` 实现由 `dispose()` 关闭自己建的连接池与 socket；宿主传入的对象带走自己的生命周期。

## 用法

绝大多数宿主只需要适配器：

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
await cast.setMute(true);                        // 同上，静音走 Master 通道
await cast.stopCasting();                        // 设备留在 devices，只结束会话

// 本地文件同样一句话：后端自动经 MediaHttpServer 以 Token URL 投送，
// 电视按 Range 拉流；本机路径不会出现在 CurrentURI 或 DIDL 里。
await cast.cast(tv, CastMedia(url: 'D:/Movies/第四集.mkv', title: '第四集'));

await backend.dispose();                         // 关发现、socket 与自有媒体服务器
```

协议核心也能单独用——自建控制器、做诊断或构建上层能力：

```dart
final manager = DlnaDiscoveryManager(
  options: DlnaDiscoveryOptions(searchInterval: Duration(seconds: 20)),
);
manager.devicesStream.listen((devices) => render(devices));
manager.errors.listen((failure) => log(failure.usn, failure.error));
await manager.start();
await manager.refresh();                          // 立即补一轮 M-SEARCH

final device = manager.device('uuid:...');
final client = SoapClient(transport: HttpSoapTransport(), timeout: Duration(seconds: 5));
final result = await client.invoke(service: device!.avTransport!, action: 'GetTransportInfo');

final scpd = ServiceDescriptionParser.parse(await fetch(device.avTransport!.scpdUrl!));
final canSeek = scpd.supportsAction('Seek');      // 能力看 SCPD，不看规范

// 能力协商：电视能播什么，由它自己的 GetProtocolInfo 回答。
final capability = await DlnaCapabilityResolver(client: client)
    .resolve(device.connectionManager!);            // 探测失败返回 unknown，不抛
final selection = const DlnaMediaSelector().select(
  media: myMedia,                                   // DlnaMedia + 多个 DlnaMediaResource
  capability: capability,
);
// selection.resource 即应投送的资源；requiresTranscoding 表示需要上游转码。

// 本地文件投送：起一个 Token 化的 Range 媒体服务器。
final server = MediaHttpServer();                   // 默认选局域网地址 + 动态端口
await server.start();
final url = await server.registerFile(File('D:/Movies/第四集.mkv'));
// url = http://192.168.x.x:port/{token}/{id}，电视可 GET/HEAD/Range，过期可清扫
server.unregister(url);

final hints = BonsoirDiscoveryChannel();          // 辅助 mDNS 通道，可选
hints.serviceFound.listen((hint) => debugPrint('$hint'));
await hints.start();

// 投屏会话（Phase 6/7）：串行命令队列 + GENA 推送（轮询保底）。或直接用门面：
final dlna = DlnaClient();
await dlna.startDiscovery();
await for (final devices in dlna.devices) {
  if (devices.isNotEmpty) break;
}
final tv2 = dlna.devicesSnapshot.first;
final prepared = await dlna.prepareMedia(          // 本地文件重写 + 能力选择
  device: tv2, title: '第四集', url: 'D:/Movies/第四集.mkv',
);
final session = await dlna.connect(tv2);           // 每设备一个活动会话
session.playbackStateStream.listen((state) => paint(state));
await session.setMedia(prepared);                  // SetAVTransportURI → 状态验证
await session.play();
await session.seek(const Duration(minutes: 3));    // 校验负值/超时长；SCPD 无 Seek 就地拒绝
await session.setVolume(40);                       // RenderingControl；没这服务抛 DlnaSessionException
await session.setMute(muted: false);
// 设备离网时：网络类失败自动进入 Reconnecting——重解析描述（IP 可能变了）、
// 重建服务与 GENA、探活后回到 Connected；超过策略次数则 Failed（可配置）。
await session.stop();                              // 取消队列里还没跑的命令
await dlna.disconnect(session);                    // 该设备的媒体资源一并注销
await dlna.dispose();
```

## 平台支持

| 平台 | 状态 |
| --- | --- |
| Android / iOS / macOS / Windows / Linux | ✅ Dart 实现：`RawDatagramSocket`（UDP 组播）+ `HttpClient` + Bonsoir（mDNS，可选举措） |
| Web | ❌ 依赖 `dart:io`，浏览器里跑不了 |
| 局域网权限 | ⏳ 在宿主：Android 多播锁、iOS `NSLocalNetworkUsageDescription`、Windows 防火墙入站规则都由宿主配置；缺失的表现是收不到 NOTIFY 通告（M-SEARCH 的单播回包通常仍能到） |

发现流量只落在标准组播组 `239.255.255.250:1900`；mDNS 流量由 Bonsoir 按标准端口处理。本包不上传设备信息、不持久化任何设备身份：`DlnaDevice` 只活在内存里，`dispose()` 即清空。响应体一律限量读取（`maxCastResponseBodyBytes`，1 MiB），描述位置只接受 `http`/`https`——URL 来自局域网里任何一台应答者的报文，不能当成可信输入。

## pure_live 接入

参考 `F:/pure_live/player-lab` 的 `lib/main.dart`：`DlnaCastBackend` 交给 media_core 的
`CastController` 即得到可监听的设备列表与传输状态；本地文件投送走 `prepareMedia` 重写。
注意与 media_kit 共存时的 `wakelock_plus` override（dbus 版本冲突，player-lab 已示范）。

## 相关文档

- 技术规范与实施阶段：[TECHNICAL_DESIGN.md](TECHNICAL_DESIGN.md)
- 契约与控制器：[../media_core](../media_core)（`lib/casting/`：`MediaCastBackend`、`CastController`、`CastDevice`、`CastMedia`、`CastPosition`）
- 界面层（投屏入口与弹层归宿主）：[../media_core_ui](../media_core_ui)
- 仓库总览：[../../README.md](../../README.md)
