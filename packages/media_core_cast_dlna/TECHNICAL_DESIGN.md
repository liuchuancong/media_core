# media_core_cast_dlna
# DLNA / UPnP 投屏技术设计与实施规范

- 项目：media_core
- Package：media_core_cast_dlna
- 技术栈：Dart / Flutter
- 协议：DLNA / UPnP AV
- 主要角色：UPnP Control Point
- 发现协议：SSDP
- 设备描述：UPnP Device Description
- 控制协议：SOAP over HTTP
- 状态订阅：GENA
- 媒体传输：HTTP / DLNA
- 文档版本：1.0.0
- 状态：设计规范
- 交付状态（2026-11）：Phase 0～9 代码与测试全部完成（含 §25 日志与诊断快照、Phase 10 代码侧的生命周期压力测试）；Phase 10 真机部分（多平台构建矩阵、长时间播放与断网恢复实测、厂商 profile 实测填充、正式 Release）待真机环境执行

---

# 目录

1. 项目定位
2. 设计目标
3. 功能范围
4. 协议基础
5. 整体架构
6. 目录结构
7. 依赖管理
8. 核心领域模型
9. 设备发现系统
10. SSDP 协议实现
11. 设备描述解析
12. 服务描述解析
13. UPnP SOAP 控制
14. GENA 状态订阅
15. DLNA 媒体能力协商
16. 媒体资源管理
17. HTTP 媒体服务器
18. 投屏播放控制
19. 播放状态同步
20. 设备连接生命周期
21. 错误处理
22. 安全设计
23. 并发与资源管理
24. 多平台适配
25. 日志与诊断
26. 测试规范
27. 开发实施阶段
28. 验收标准
29. 性能要求
30. AI 开发规范
31. 后续扩展
32. 参考资料

---

# 1. 项目定位

## 1.1 项目职责

media_core_cast_dlna 是 media_core 生态中的独立 DLNA 投屏协议实现包。

它负责让 PureLive 作为 DLNA Control Point，在局域网中发现兼容的电视、电视盒子、媒体渲染器等设备，并向设备发送媒体播放控制指令。

主要工作流程：

1. 搜索局域网内的 DLNA Renderer。
2. 获取设备 IP、端口和设备描述地址。
3. 解析设备能力与服务信息。
4. 获取 AVTransport、RenderingControl 等服务。
5. 建立投屏会话。
6. 选择兼容的媒体资源。
7. 将媒体资源地址发送给电视。
8. 控制电视播放、暂停、停止和跳转。
9. 订阅设备播放状态。
10. 处理设备离线、连接失败和播放异常。

## 1.2 项目边界

本包只实现 DLNA / UPnP 协议。

不负责：

- Google Cast。
- AirPlay。
- Miracast。
- 桌面屏幕镜像。
- Flutter 投屏 UI。
- 播放器 UI。
- 本地媒体库。
- 直播站点解析。
- 视频解码。
- 音频解码。

## 1.3 与 media_core 的关系

```text
media_core
│
├── media_core_media_kit
│   └── 本地媒体播放引擎
│
├── media_core_playback
│   └── 统一播放控制
│
├── media_core_cast_dlna
│   └── DLNA 投屏协议
│
├── media_core_cast_google
│   └── Google Cast（独立包）
│
├── media_core_cast_airplay
│   └── AirPlay（独立包）
│
└── pure_live
    └── 投屏 UI 与业务编排
```

注意：

media_core_cast_dlna 不应该依赖 media_core_media_kit。

投屏设备拥有自己的解码和播放能力，本地播放器与远程 Renderer 是两个独立的播放执行端。

---

# 2. 设计目标

## 2.1 核心目标

- 支持跨平台设备发现。
- 支持标准 UPnP 设备描述。
- 支持多种 DLNA Renderer。
- 支持 HTTP 媒体投送。
- 支持常见视频、音频和图片。
- 支持播放控制。
- 支持播放状态同步。
- 支持多个设备同时发现。
- 支持设备断线恢复。
- 支持设备能力检测。
- 支持不同电视厂商的协议兼容处理。

## 2.2 设计原则

### 协议与业务分离

协议层只负责协议通信。

不要将设备搜索、媒体选择、播放控制、UI 状态混合在同一个类中。

### 能力驱动

不能假设所有 DLNA 设备支持相同功能。

必须根据设备实际暴露的服务和动作确定可用能力。

### 标准优先

优先使用 UPnP 标准服务与标准动作。

厂商特殊处理必须通过独立兼容层完成。

### 可替换基础设施

SSDP、HTTP、媒体服务器、XML 解析都应该有独立抽象。

不能让领域模型依赖某个 Flutter 插件。

### 异步与响应式

设备发现、连接、播放状态都需要提供 Stream。

避免通过轮询 UI 或直接暴露底层网络 Socket 来管理状态。

---

# 3. 功能范围

## 3.1 第一阶段必须实现

| 功能 | 优先级 |
|---|---|
| SSDP 设备发现 | P0 |
| 设备描述解析 | P0 |
| AVTransport 服务 | P0 |
| SOAP 控制 | P0 |
| URI 投送 | P0 |
| 播放控制 | P0 |
| 设备离线检测 | P0 |
| HTTP 媒体服务器 | P0 |
| 设备能力检测 | P0 |
| 错误处理 | P0 |

## 3.2 第二阶段实现

| 功能 | 优先级 |
|---|---|
| GENA 状态订阅 | P1 |
| RenderingControl | P1 |
| 音量控制 | P1 |
| 播放进度同步 | P1 |
| Seek 跳转 | P1 |
| DLNA Profile 协商 | P1 |
| 多设备管理 | P1 |
| 设备能力缓存 | P1 |

## 3.3 第三阶段实现

| 功能 | 优先级 |
|---|---|
| 厂商兼容策略 | P2 |
| 多资源自动选择 | P2 |
| 转码适配接口 | P2 |
| 图片投屏 | P2 |
| 字幕投送 | P2 |
| 播放队列 | P2 |
| 播放失败自动恢复 | P2 |

## 3.4 暂不实现

- Miracast。
- HDMI 输出。
- 远程电视桌面控制。
- 电视应用安装。
- 电视系统设置修改。
- 依赖厂商私有接口的完整控制。

---

# 4. 协议基础

DLNA 通常建立在 UPnP AV 体系上。

本项目主要使用以下协议。

## 4.1 SSDP

Simple Service Discovery Protocol。

负责发现局域网设备。

常用地址：

```text
239.255.255.250:1900
```

主要消息：

```text
M-SEARCH
NOTIFY
HTTP/1.1 200 OK
```

主要用途：

- 主动搜索设备。
- 监听设备上线。
- 监听设备下线。
- 维护设备缓存。
- 处理设备存活时间。

SSDP 使用 UDP，不是 mDNS。

因此：

Bonsoir 不能替代 SSDP。

## 4.2 UPnP Device Description

通过 HTTP 获取设备 XML 描述。

一般包含：

- deviceType
- friendlyName
- manufacturer
- modelName
- modelNumber
- UDN
- serviceList
- presentationURL

## 4.3 SOAP

通过 HTTP POST 调用 UPnP 服务动作。

例如：

```text
SetAVTransportURI
Play
Pause
Stop
Seek
GetPositionInfo
GetTransportInfo
```

## 4.4 GENA

General Event Notification Architecture。

用于接收设备主动发送的状态变化通知。

例如：

- TransportState。
- CurrentTrackURI。
- RelativeTimePosition。
- Volume。
- Mute。

使用 HTTP SUBSCRIBE / UNSUBSCRIBE 和 NOTIFY。

## 4.5 DLNA

DLNA 负责定义媒体共享、媒体格式与设备互操作相关要求。

需要关注：

- MIME Type。
- ProtocolInfo。
- DLNA Profile。
- DLNA.ORG_OP。
- DLNA.ORG_CI。
- HTTP Range。
- Content-Length。
- Content-Range。

不能只把视频 URL 发送给电视就认为完成了 DLNA 兼容。

---

# 5. 整体架构

## 5.1 架构分层

```text
media_core_cast_dlna
│
├── Domain
│   ├── Entities
│   ├── Value Objects
│   ├── Enums
│   ├── Exceptions
│   └── Contracts
│
├── Application
│   ├── Discovery
│   ├── Device Management
│   ├── Connection
│   ├── Media Selection
│   ├── Playback
│   └── Session Management
│
├── Infrastructure
│   ├── SSDP
│   ├── HTTP
│   ├── SOAP
│   ├── GENA
│   ├── XML
│   ├── Media Server
│   └── Compatibility
│
└── Public API
    ├── Client
    ├── Configuration
    └── Events
```

## 5.2 数据流

```text
                 PureLive
                     │
                     ▼
              DLNA Client
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
    Discovery Service     Session Manager
          │                     │
          ▼                     ▼
       SSDP Layer          Playback Service
          │                     │
          ▼                     ▼
      UDP Multicast          SOAP Layer
          │                     │
          ▼                     ▼
      DLNA Device          HTTP Control
                                │
                                ▼
                          DLNA Renderer
                                │
                                ▼
                          Media Server
                                │
                                ▼
                           Media Stream
```

## 5.3 设备播放流程

```text
用户选择设备
    │
    ▼
检查设备能力
    │
    ▼
选择媒体资源
    │
    ▼
启动本地 HTTP 服务
    │
    ▼
生成媒体访问 URL
    │
    ▼
SetAVTransportURI
    │
    ▼
Play
    │
    ▼
设备开始请求媒体
    │
    ▼
HTTP Server 发送媒体数据
    │
    ▼
GENA / 查询接口同步状态
```

---

# 6. 目录结构

必须采用清晰的模块化结构。

```text
media_core_cast_dlna/
│
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
├── TECHNICAL_DESIGN.md
├── analysis_options.yaml
│
├── lib/
│   ├── media_core_cast_dlna.dart
│   │
│   └── src/
│       │
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── dlna_device.dart
│       │   │   ├── dlna_service.dart
│       │   │   ├── dlna_session.dart
│       │   │   ├── dlna_media.dart
│       │   │   ├── dlna_media_resource.dart
│       │   │   └── dlna_playback_state.dart
│       │   │
│       │   ├── value_objects/
│       │   │   ├── device_udn.dart
│       │   │   ├── device_location.dart
│       │   │   ├── service_type.dart
│       │   │   ├── control_url.dart
│       │   │   ├── event_sub_url.dart
│       │   │   └── media_protocol_info.dart
│       │   │
│       │   ├── enums/
│       │   │   ├── dlna_device_type.dart
│       │   │   ├── dlna_service_type.dart
│       │   │   ├── dlna_transport_state.dart
│       │   │   ├── dlna_connection_state.dart
│       │   │   ├── dlna_media_type.dart
│       │   │   └── dlna_error_code.dart
│       │   │
│       │   ├── contracts/
│       │   │   ├── device_discovery.dart
│       │   │   ├── device_repository.dart
│       │   │   ├── soap_transport.dart
│       │   │   ├── media_server.dart
│       │   │   └── event_subscriber.dart
│       │   │
│       │   └── exceptions/
│       │       ├── dlna_exception.dart
│       │       ├── dlna_network_exception.dart
│       │       ├── dlna_protocol_exception.dart
│       │       └── dlna_device_exception.dart
│       │
│       ├── application/
│       │   ├── discovery/
│       │   │   ├── dlna_discovery_manager.dart
│       │   │   └── dlna_discovery_options.dart
│       │   │
│       │   ├── device/
│       │   │   ├── dlna_device_manager.dart
│       │   │   └── dlna_device_registry.dart
│       │   │
│       │   ├── connection/
│       │   │   ├── dlna_connection_manager.dart
│       │   │   └── dlna_session_manager.dart
│       │   │
│       │   ├── media/
│       │   │   ├── dlna_media_selector.dart
│       │   │   ├── dlna_media_resolver.dart
│       │   │   └── dlna_media_capability.dart
│       │   │
│       │   ├── playback/
│       │   │   ├── dlna_playback_controller.dart
│       │   │   ├── dlna_playback_monitor.dart
│       │   │   └── dlna_playback_queue.dart
│       │   │
│       │   └── session/
│       │       └── dlna_session_controller.dart
│       │
│       ├── infrastructure/
│       │   ├── discovery/
│       │   │   ├── ssdp/
│       │   │   │   ├── ssdp_client.dart
│       │   │   │   ├── ssdp_message.dart
│       │   │   │   ├── ssdp_parser.dart
│       │   │   │   ├── ssdp_search.dart
│       │   │   │   ├── ssdp_listener.dart
│       │   │   │   └── ssdp_constants.dart
│       │   │   │
│       │   │   └── bonsoir/
│       │   │       └── bonsoir_discovery.dart
│       │   │
│       │   ├── description/
│       │   │   ├── device_description_parser.dart
│       │   │   ├── service_description_parser.dart
│       │   │   └── xml_parser.dart
│       │   │
│       │   ├── control/
│       │   │   ├── soap/
│       │   │   │   ├── soap_client.dart
│       │   │   │   ├── soap_request_builder.dart
│       │   │   │   ├── soap_response_parser.dart
│       │   │   │   └── soap_fault_parser.dart
│       │   │   │
│       │   │   ├── services/
│       │   │   │   ├── av_transport_service.dart
│       │   │   │   ├── rendering_control_service.dart
│       │   │   │   └── connection_manager_service.dart
│       │   │   │
│       │   │   └── gena/
│       │   │       ├── gena_subscriber.dart
│       │   │       ├── gena_callback_server.dart
│       │   │       ├── gena_message_parser.dart
│       │   │       └── gena_subscription.dart
│       │   │
│       │   ├── media/
│       │   │   ├── http/
│       │   │   │   ├── media_http_server.dart
│       │   │   │   ├── media_http_handler.dart
│       │   │   │   ├── media_http_headers.dart
│       │   │   │   └── media_http_range.dart
│       │   │   │
│       │   │   ├── protocol_info_parser.dart
│       │   │   └── media_resource_builder.dart
│       │   │
│       │   ├── network/
│       │   │   ├── network_interface_provider.dart
│       │   │   ├── ip_address_selector.dart
│       │   │   └── network_validator.dart
│       │   │
│       │   └── compatibility/
│       │       ├── device_compatibility_registry.dart
│       │       ├── device_compatibility_profile.dart
│       │       └── profiles/
│       │
│       ├── models/
│       │   ├── ssdp_response.dart
│       │   ├── device_description.dart
│       │   ├── service_description.dart
│       │   ├── soap_action_result.dart
│       │   └── gena_event.dart
│       │
│       └── utils/
│           ├── duration_parser.dart
│           ├── xml_utils.dart
│           └── network_utils.dart
│
└── test/
    ├── domain/
    ├── application/
    ├── infrastructure/
    │   ├── ssdp/
    │   ├── soap/
    │   ├── gena/
    │   └── media/
    └── fixtures/
```

说明：

以上是完整目标结构，不要求第一阶段一次性创建所有文件。

必须按照开发阶段逐步建立目录。

不要提前创建大量空文件。

---

# 7. 依赖管理

## 7.1 核心依赖

建议：

```yaml
dependencies:
  flutter:
    sdk: flutter

  bonsoir: ^7.1.6
```

Bonsoir 仅用于 mDNS / DNS-SD 服务发现，不作为 SSDP 实现。

如果后续确实需要 HTTP、XML 等第三方依赖，应先评估 media_core 已有的 live_net、XML 工具和现有基础设施。

避免重复实现同一套通用 HTTP 能力。

## 7.2 SSDP

SSDP 使用 Dart UDP Socket。

建议使用：

```dart
RawDatagramSocket.bind(...)
```

具体实现应封装在 SSDP Infrastructure 内。

不要在 Domain 层直接使用 Socket。

## 7.3 HTTP

HTTP 客户端应该通过独立接口注入。

需要支持：

- GET。
- POST。
- SUBSCRIBE。
- UNSUBSCRIBE。
- 自定义请求头。
- 超时。
- 取消。
- 响应状态码。
- XML 响应体。

如果 media_core 已有 live_net，应优先复用其底层网络能力，但不能让 DLNA 领域层直接依赖某个具体 HTTP 实现。

## 7.4 XML

需要支持：

- XML 文档解析。
- Namespace。
- 属性解析。
- 嵌套元素。
- SOAP Envelope。
- SOAP Fault。
- UPnP Device Description。

不要通过简单字符串切割解析 XML。

---

# 8. 核心领域模型

## 8.1 DlnaDevice

表示一个发现的 DLNA 设备。

建议包含：

```dart
class DlnaDevice {
  final String udn;
  final String friendlyName;

  final String manufacturer;
  final String modelName;
  final String modelNumber;

  final Uri location;
  final Uri? presentationUrl;

  final String deviceType;

  final List<DlnaService> services;

  final DateTime discoveredAt;
  final DateTime? lastSeenAt;

  final Duration maxAge;
}
```

要求：

- UDN 是设备稳定标识。
- IP 地址不是设备唯一标识。
- 设备名称不能作为唯一标识。
- 同一 UDN 的设备重新发现时应该更新记录。
- 设备 IP 变化时应重新验证设备描述地址。

## 8.2 DlnaService

表示设备提供的 UPnP 服务。

```dart
class DlnaService {
  final String serviceType;
  final String serviceId;

  final Uri controlUrl;
  final Uri eventSubUrl;
  final Uri scpdUrl;

  final String? version;
}
```

所有 URL 必须根据设备描述文档中的 URLBase 和描述文档地址正确解析。

不能简单拼接字符串。

## 8.3 DlnaSession

表示与 Renderer 建立的投屏会话。

```dart
class DlnaSession {
  final String id;
  final DlnaDevice device;

  final DateTime createdAt;

  final DlnaConnectionState connectionState;

  final DlnaPlaybackState playbackState;
}
```

Session 与 Device 必须分离。

一个设备可以在不同时间建立多个 Session。

同一设备不允许在同一 Session 中同时执行互相冲突的播放控制操作。

## 8.4 DlnaMedia

表示待投送媒体。

```dart
class DlnaMedia {
  final String id;

  final String title;
  final DlnaMediaType mediaType;

  final Uri sourceUri;

  final Duration? duration;

  final String? mimeType;

  final List<DlnaMediaResource> resources;
}
```

媒体资源不应该直接等同于原始播放 URL。

## 8.5 DlnaMediaResource

表示具体的可投送资源。

```dart
class DlnaMediaResource {
  final Uri uri;

  final String mimeType;

  final String protocolInfo;

  final int? size;

  final Duration? duration;

  final bool supportsByteRange;
}
```

同一视频可能有多个候选资源。

例如：

```text
Resource A:
video/mp4
H.264 + AAC

Resource B:
video/webm
VP9 + Opus

Resource C:
video/mpeg
MPEG-TS
```

应该根据设备能力选择最适合的资源。

## 8.6 播放状态

至少包含：

```dart
enum DlnaTransportState {
  stopped,
  playing,
  paused,
  transitioning,
  noMediaPresent,
  unknown,
}
```

还需要区分：

- 当前媒体信息。
- 当前播放位置。
- 总时长。
- 播放速度。
- 当前设备音量。
- 静音状态。
- 设备连接状态。

---

# 9. 设备发现系统

## 9.1 发现架构

设备发现采用双通道设计：

```text
DiscoveryManager
│
├── SSDP Discovery
│   ├── M-SEARCH
│   ├── NOTIFY Listener
│   └── Device Registry
│
└── Bonsoir Discovery
    ├── mDNS Browser
    └── DNS-SD Resolver
```

其中：

SSDP 是 DLNA / UPnP 设备发现的主要方式。

Bonsoir 是辅助发现通道。

不能因为设备支持 mDNS 就认为它支持 DLNA。

也不能因为设备没有广播 mDNS 就认为它不支持 DLNA。

## 9.2 SSDP 搜索目标

至少搜索：

```text
ssdp:all

upnp:rootdevice

urn:schemas-upnp-org:device:MediaRenderer:1

urn:schemas-upnp-org:service:AVTransport:1

urn:schemas-upnp-org:service:RenderingControl:1
```

不同设备可能只响应部分搜索目标。

建议使用分批搜索和设备去重。

## 9.3 M-SEARCH

请求示例：

```http
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: 3
ST: urn:schemas-upnp-org:device:MediaRenderer:1

```

要求：

- 使用 UDP。
- 支持多次搜索。
- 支持搜索超时。
- 解析 HTTP 风格响应头。
- 支持不同大小写的 Header。
- 忽略不合法响应。
- 支持多设备并发响应。
- 支持设备去重。

MX 是设备响应允许延迟的时间窗口。

不要让设备搜索依赖单次 UDP 数据包。

## 9.4 NOTIFY

监听：

```text
ssdp:alive
ssdp:byebye
ssdp:update
```

处理逻辑：

```text
ssdp:alive
    -> 添加或刷新设备

ssdp:byebye
    -> 标记设备离线

ssdp:update
    -> 重新验证设备信息
```

NOTIFY 的缓存时间来自 CACHE-CONTROL 中的 max-age。

不能永久缓存设备。

## 9.5 设备去重

优先使用 UDN。

没有 UDN 的初始 SSDP 响应可以暂时通过 USN 关联。

不得直接通过 IP 地址去重。

原因：

- 多个设备可能共享一个 IP 代理地址。
- 设备 DHCP 地址可能变化。
- 一个设备可能响应多个 ST。
- 一个设备可能广播多个 USN。

## 9.6 设备发现状态

```dart
enum DlnaDiscoveryState {
  idle,
  starting,
  searching,
  active,
  stopping,
  stopped,
  error,
}
```

发现结果通过 Stream 输出。

建议提供：

```dart
Stream<List<DlnaDevice>> get devices;

Stream<DlnaDevice> get deviceAdded;

Stream<DlnaDevice> get deviceUpdated;

Stream<String> get deviceRemoved;
```

## 9.7 搜索生命周期

必须支持：

```text
startDiscovery()
stopDiscovery()
refreshDiscovery()
dispose()
```

重复调用 startDiscovery 不应该产生多个 UDP Listener。

stopDiscovery 必须释放：

- UDP Socket。
- StreamSubscription。
- 定时器。
- 设备搜索任务。
- 临时缓存。

---

# 10. SSDP 协议实现

## 10.1 SSDP Client

负责：

- 创建 UDP Socket。
- 加入 SSDP Multicast Group。
- 发送 M-SEARCH。
- 接收响应。
- 监听 NOTIFY。
- 解析 SSDP Header。
- 管理 Socket 生命周期。

## 10.2 SSDP Parser

需要解析：

```text
LOCATION
USN
ST
NT
NTS
CACHE-CONTROL
SERVER
BOOTID.UPNP.ORG
CONFIGID.UPNP.ORG
SEARCHPORT.UPNP.ORG
```

Header 名称比较必须不区分大小写。

## 10.3 LOCATION

LOCATION 指向设备描述 XML。

例如：

```text
http://192.168.1.100:8200/rootDesc.xml
```

需要：

1. 验证 URL。
2. 验证协议。
3. 检查目标 IP。
4. 检查端口。
5. 进行 HTTP GET。
6. 解析 XML。

LOCATION 是网络输入，不能无条件访问。

必须执行安全校验。

## 10.4 网络接口

需要考虑：

- Wi-Fi。
- Ethernet。
- 多网卡。
- VPN。
- 虚拟网卡。
- IPv4。
- IPv6。

默认优先使用当前局域网接口。

不要默认选择：

- Loopback。
- VPN 虚拟接口。
- 无效接口。
- 未连接接口。

多网卡环境应允许指定网络接口。

## 10.5 多播限制

不同平台对 UDP Multicast 的处理存在差异。

必须通过真实设备进行验证。

不能只依赖 Flutter 模拟器测试 SSDP。

---

# 11. 设备描述解析

## 11.1 Device Description

获取设备描述：

```http
GET /rootDesc.xml HTTP/1.1
HOST: 192.168.1.100:8200
```

常见 XML：

```xml
<root>
  <device>
    <deviceType>
      urn:schemas-upnp-org:device:MediaRenderer:1
    </deviceType>

    <friendlyName>Living Room TV</friendlyName>

    <manufacturer>Example</manufacturer>

    <modelName>Smart TV</modelName>

    <UDN>uuid:xxxxxxxx</UDN>

    <serviceList>
      ...
    </serviceList>
  </device>
</root>
```

## 11.2 解析规则

必须支持：

- XML Namespace。
- 可选字段。
- 多级嵌套 device。
- 多个 service。
- URLBase。
- XML 编码。
- 无效 XML。
- 缺少字段。
- 不规范设备描述。

不能假设 friendlyName 一定存在。

不能假设设备只暴露一个 serviceList。

## 11.3 服务地址解析

服务地址通常包括：

```text
SCPDURL
controlURL
eventSubURL
```

解析规则：

1. 优先使用合法 URLBase。
2. 否则使用 LOCATION 的基础地址。
3. 使用 Uri.resolve。
4. 保留原始 scheme、host、port。
5. 拒绝不安全的目标地址。

禁止：

```dart
final url = baseUrl + controlUrl;
```

必须使用 URI 解析。

## 11.4 MediaRenderer 识别

优先识别：

```text
urn:schemas-upnp-org:device:MediaRenderer:1
urn:schemas-upnp-org:device:MediaRenderer:2
```

不能仅根据设备名称判断是否支持 DLNA。

必须检查设备类型及服务能力。

---

# 12. 服务描述解析

## 12.1 SCPD

UPnP 服务通过 SCPD 描述支持的 Action 和 State Variable。

例如：

```text
scpd.xml
```

需要解析：

- actionList。
- action name。
- argumentList。
- argument name。
- direction。
- relatedStateVariable。
- serviceStateTable。
- dataType。
- allowedValueList。
- allowedValueRange。

## 12.2 服务识别

主要服务：

```text
AVTransport
urn:schemas-upnp-org:service:AVTransport:1

RenderingControl
urn:schemas-upnp-org:service:RenderingControl:1

ConnectionManager
urn:schemas-upnp-org:service:ConnectionManager:1
```

版本应按设备实际提供的服务确定。

## 12.3 AVTransport

主要职责：

- 设置媒体 URL。
- 播放。
- 暂停。
- 停止。
- Seek。
- 获取播放状态。
- 获取当前媒体信息。
- 获取播放位置。

## 12.4 RenderingControl

主要职责：

- 获取音量。
- 设置音量。
- 获取静音状态。
- 设置静音状态。

## 12.5 ConnectionManager

主要职责：

- 获取协议能力。
- 获取当前连接信息。
- 获取连接信息列表。

注意：

不是所有设备都完整实现所有服务。

缺少非必要服务时不能直接判定设备不可用。

---

# 13. UPnP SOAP 控制

## 13.1 SOAP Client

负责统一执行 SOAP Action。

输入：

```text
Service
Action
Arguments
```

输出：

```text
SoapActionResult
```

统一处理：

- XML Envelope。
- HTTP POST。
- SOAPAction Header。
- HTTP 状态码。
- XML 响应。
- UPnP Error Code。
- SOAP Fault。
- 请求超时。
- 请求取消。

## 13.2 SOAP 请求示例

SetAVTransportURI：

```http
POST /upnp/control/AVTransport HTTP/1.1
Content-Type: text/xml; charset="utf-8"
SOAPAction: "urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"
```

请求体：

```xml
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope
 xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
 s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">

  <s:Body>
    <u:SetAVTransportURI
      xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">

      <InstanceID>0</InstanceID>

      <CurrentURI>http://192.168.1.10:8080/media/video.mp4</CurrentURI>

      <CurrentURIMetaData></CurrentURIMetaData>

    </u:SetAVTransportURI>
  </s:Body>
</s:Envelope>
```

## 13.3 必须实现的 Action

### AVTransport

```text
SetAVTransportURI
SetNextAVTransportURI
Play
Pause
Stop
Seek
Next
Previous
GetTransportInfo
GetPositionInfo
GetMediaInfo
GetDeviceCapabilities
GetTransportSettings
SetPlayMode
```

注意：

必须根据 SCPD 判断设备是否真正支持这些 Action。

不要因为 Action 名称在规范中存在就认为设备一定支持。

### RenderingControl

```text
GetVolume
SetVolume
GetMute
SetMute
```

### ConnectionManager

```text
GetProtocolInfo
GetCurrentConnectionIDs
GetCurrentConnectionInfo
```

## 13.4 InstanceID

大部分基础 Renderer 使用：

```text
InstanceID = 0
```

但不能在所有设备上硬编码。

应该根据服务和设备能力进行适配。

## 13.5 参数校验

Seek 必须校验：

- 设备支持 Seek。
- 时间格式合法。
- 当前媒体允许跳转。
- 时间不能为负数。
- 不能超过已知总时长。

标准时间格式：

```text
HH:MM:SS
```

必要时支持小数秒。

## 13.6 UPnP 错误

需要识别：

```text
401 Invalid Action
402 Invalid Args
501 Action Failed
701 Transition Unavailable
702 No Contents
703 Read Error
704 Format Not Supported
705 Transport Locked
```

错误码必须结合对应服务规范和设备响应处理。

不能把所有 SOAP Fault 都当成网络错误。

---

# 14. GENA 状态订阅

## 14.1 目的

通过 GENA 获取设备主动推送的状态。

相比持续轮询，可以减少网络请求。

## 14.2 订阅流程

```text
启动本地 Callback Server
        │
        ▼
生成 Callback URL
        │
        ▼
发送 SUBSCRIBE
        │
        ▼
设备返回 SID
        │
        ▼
保存订阅状态
        │
        ▼
设备发送 NOTIFY
        │
        ▼
解析状态变化
        │
        ▼
更新 Playback State
```

## 14.3 SUBSCRIBE

请求头：

```http
SUBSCRIBE /upnp/event/AVTransport HTTP/1.1
CALLBACK: <http://192.168.1.10:8081/callback>
NT: upnp:event
TIMEOUT: Second-1800
```

响应：

```http
HTTP/1.1 200 OK
SID: uuid:xxxxxxxx
TIMEOUT: Second-1800
```

## 14.4 NOTIFY

必须处理：

```text
SID
SEQ
NT
NTS
Content-Type
```

需要解析 XML PropertySet。

## 14.5 状态变量

重点监听：

```text
TransportState
TransportStatus
CurrentTrackURI
CurrentTrackDuration
RelativeTimePosition
AbsoluteTimePosition
Volume
Mute
```

不同设备的状态变量支持情况可能不同。

## 14.6 续订

设备返回的 TIMEOUT 是订阅有效期。

应该在过期前续订。

必须支持：

```text
SUBSCRIBE renewal
UNSUBSCRIBE
```

设备离线时及时清理订阅。

## 14.7 Callback Server

Callback Server 是 GENA 的必要基础设施。

必须处理：

- 随机可用端口。
- 本机局域网地址。
- HTTP NOTIFY。
- SID 校验。
- SEQ 去重。
- 请求超时。
- 订阅释放。

注意：

不能默认 HTTP Callback Server 在所有设备上都可访问。

防火墙、网络隔离、设备实现差异都可能导致订阅失败。

GENA 失败时必须自动回退到轮询模式。

---

# 15. DLNA 媒体能力协商

## 15.1 为什么需要能力协商

电视不一定支持所有媒体格式。

例如：

```text
视频：
H.264
H.265
VP9
AV1

容器：
MP4
MKV
TS
WebM

音频：
AAC
MP3
AC3
EAC3
Opus
FLAC
```

设备支持容器，不代表支持容器内所有编码。

必须综合判断：

- 容器。
- 视频编码。
- 音频编码。
- 分辨率。
- 帧率。
- Profile。
- Level。
- MIME Type。
- DLNA Profile。

## 15.2 能力来源

主要来源：

1. ConnectionManager.GetProtocolInfo。
2. 设备 SCPD。
3. DLNA 设备描述。
4. 设备厂商兼容配置。
5. 已知设备的能力缓存。

## 15.3 ProtocolInfo

典型结构：

```text
protocol:network:contentFormat:additionalInfo
```

例如：

```text
http-get:*:video/mp4:*
```

或者：

```text
http-get:*:video/mp4:DLNA.ORG_OP=01;DLNA.ORG_CI=0
```

必须正确解析冒号分隔结构。

不能简单 split 后丢失额外参数。

## 15.4 DLNA 参数

需要支持：

```text
DLNA.ORG_PN
DLNA.ORG_OP
DLNA.ORG_CI
DLNA.ORG_FLAGS
```

含义：

- PN：Profile Name。
- OP：Operations。
- CI：Conversion Indicator。
- FLAGS：DLNA 能力标志。

## 15.5 媒体选择

建议评分机制：

```text
1. 是否支持媒体容器
2. 是否支持视频编码
3. 是否支持音频编码
4. 是否支持 DLNA Profile
5. 是否支持 HTTP Range
6. 是否满足设备分辨率
7. 是否需要转码
```

最终选择：

```dart
class DlnaMediaSelection {
  final DlnaMediaResource resource;

  final bool requiresTranscoding;

  final List<String> reasons;
}
```

不支持的资源不能直接投送。

## 15.6 不支持转码时

明确返回：

```text
UnsupportedMediaFormat
```

不要默默尝试所有资源。

转码能力应通过独立接口扩展，不能把 FFmpeg 直接写进 DLNA SOAP 层。

---

# 16. 媒体资源管理

## 16.1 媒体来源

支持三类资源：

### A. 公网 HTTP URL

例如：

```text
https://example.com/video.mp4
```

前提：

电视能够访问该 URL。

需要考虑：

- 电视是否能够访问公网。
- HTTPS 证书兼容性。
- 请求头。
- Cookie。
- Token。
- URL 有效期。
- 防盗链。

### B. 局域网 HTTP URL

例如：

```text
http://192.168.1.10:8080/video.mp4
```

由 PureLive 本地 HTTP Server 提供。

### C. 本地文件

例如：

```text
D:/Videos/movie.mp4
```

电视不能直接读取本机文件系统。

必须通过 HTTP Server 暴露媒体资源。

## 16.2 媒体 URL

生成 URL 时：

- 使用可被电视访问的局域网地址。
- 不使用 localhost。
- 不使用 127.0.0.1。
- 不随意使用 VPN 地址。
- 支持 IPv4。
- 正确处理 IPv6。
- 使用随机资源 Token。
- 限制资源访问权限。

## 16.3 请求头

需要正确支持：

```http
Content-Type
Content-Length
Accept-Ranges
Content-Range
Connection
```

设备可能使用 HEAD 请求。

必须正确处理 HEAD。

## 16.4 HTTP Range

这是媒体服务器的关键能力。

需要支持：

```http
Range: bytes=0-1023
```

响应：

```http
HTTP/1.1 206 Partial Content
Content-Range: bytes 0-1023/10485760
Accept-Ranges: bytes
Content-Length: 1024
```

需要处理：

- 单段 Range。
- 无效 Range。
- 超出文件范围。
- HEAD。
- GET。
- 文件大小。
- 文件流读取。
- 客户端中断。
- 资源不存在。

如果不支持 Range，部分电视可能无法正常跳转或播放。

## 16.5 直播流

PureLive 的直播资源也可能需要投屏。

必须区分：

```text
VOD:
有明确文件大小
有明确时长
支持 Range 的可能性较高

LIVE:
持续增长或无限流
时长未知
可能不支持 Range
```

直播流不能默认按普通 MP4 文件处理。

对于 HLS：

```text
m3u8
  ├── master playlist
  ├── media playlist
  └── ts / m4s segments
```

如果使用本地代理：

必须确保播放列表中的分片 URL 对电视可访问。

不能只代理 m3u8 文件而忽略内部资源地址。

还要处理相对 URL、跨域、认证参数和直播清单刷新。

## 16.6 媒体元数据

SetAVTransportURI 应尽可能携带 DIDL-Lite 元数据。

基本结构：

```xml
<DIDL-Lite
 xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">

  <item id="1" parentID="0" restricted="1">

    <dc:title>Example Video</dc:title>

    <upnp:class>
      object.item.videoItem
    </upnp:class>

    <res
      protocolInfo="http-get:*:video/mp4:*">
      http://192.168.1.10:8080/video.mp4
    </res>

  </item>

</DIDL-Lite>
```

XML 必须正确转义。

URI 中的特殊字符不能破坏 XML。

---

# 17. HTTP 媒体服务器

## 17.1 职责

媒体服务器负责将本地或代理媒体资源提供给 Renderer。

它不是完整的 Web Server。

只提供投屏所需要的 HTTP 能力。

## 17.2 生命周期

```text
Idle
  │
  ▼
Starting
  │
  ▼
Running
  │
  ▼
Stopping
  │
  ▼
Stopped
```

## 17.3 端口

建议：

- 默认使用动态可用端口。
- 允许配置端口范围。
- 绑定指定局域网接口或适当的本地接口。
- 启动失败时允许重试其他端口。

## 17.4 资源管理

每个资源需要：

```text
Resource ID
Access Token
Media Source
Mime Type
File Size
Last Access Time
Expiration
```

资源应该有明确的释放机制。

停止 Session 时，不应该立即释放其他 Session 仍在使用的媒体资源。

## 17.5 并发

需要支持：

- 多个设备同时请求。
- 多个媒体资源。
- 同一资源多个 Range 请求。
- 请求中断。
- 设备重连。

禁止将完整视频一次性读入内存。

必须使用 Stream。

---

# 18. 投屏播放控制

## 18.1 播放流程

```text
准备媒体
   │
   ▼
检查设备连接
   │
   ▼
检查 AVTransport
   │
   ▼
选择媒体资源
   │
   ▼
启动 HTTP Server（必要时）
   │
   ▼
生成 DIDL-Lite
   │
   ▼
SetAVTransportURI
   │
   ▼
Play
   │
   ▼
等待设备状态变化
```

## 18.2 播放接口

```dart
abstract interface class DlnaPlaybackController {
  Future<void> setMedia(DlnaMedia media);

  Future<void> play({String speed = '1'});

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<DlnaPlaybackState> getPlaybackState();

  Future<Duration?> getPosition();

  Future<Duration?> getDuration();
}
```

## 18.3 播放状态

```text
NoMedia
Stopped
Playing
Paused
Transitioning
Unknown
```

必须正确处理设备返回的状态。

不能将 SOAP 调用成功等同于电视已经开始播放。

例如：

Play 返回成功只表示设备接受了命令。

真正的播放状态应该通过 GENA 或 GetTransportInfo 验证。

## 18.4 播放控制顺序

设置媒体：

```text
SetAVTransportURI
    ↓
Play
```

停止：

```text
Stop
```

暂停：

```text
Pause
```

跳转：

```text
Seek
```

具体动作执行前应检查设备支持情况。

## 18.5 操作并发

同一 Session 中：

- SetAVTransportURI 与 Play 必须有顺序约束。
- 连续 Seek 应支持合并或串行执行。
- Stop 应能够取消后续未执行的播放操作。
- 设备断开后不应继续执行过期操作。

建议为 Session 建立独立的命令队列。

---

# 19. 播放状态同步

## 19.1 优先使用 GENA

播放状态更新优先使用 GENA。

如果设备不支持或订阅失败，使用轮询。

## 19.2 轮询

建议默认：

```text
播放中：2~3 秒
暂停中：5~10 秒
停止中：停止频繁轮询
```

以上是初始工程策略，应允许配置。

轮询内容：

```text
GetTransportInfo
GetPositionInfo
```

避免每次刷新同时请求所有信息。

## 19.3 状态模型

```dart
class DlnaPlaybackState {
  final DlnaTransportState transportState;

  final Duration? position;

  final Duration? duration;

  final String? currentUri;

  final String? currentTitle;

  final int? volume;

  final bool? isMuted;

  final DateTime updatedAt;
}
```

## 19.4 状态冲突

当 GENA 和轮询同时更新状态时：

- 优先采用有效的最新设备状态。
- 处理事件序号。
- 忽略重复事件。
- 避免旧响应覆盖新状态。
- 不将客户端预测状态当成设备真实状态。

---

# 20. 设备连接生命周期

## 20.1 状态

```dart
enum DlnaConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  disconnecting,
  failed,
}
```

## 20.2 连接流程

```text
Disconnected
     │
     ▼
Connecting
     │
     ▼
获取设备描述
     │
     ▼
解析服务
     │
     ▼
检查 Renderer 能力
     │
     ▼
Connected
```

## 20.3 断线

出现以下情况时进入异常流程：

- 设备 IP 不可达。
- SOAP 请求超时。
- HTTP 连接失败。
- 设备停止广播。
- GENA 订阅失效。
- Renderer 服务不可用。

## 20.4 恢复

恢复流程：

1. 标记 Session 为 Reconnecting。
2. 重新检查设备地址。
3. 重新获取必要服务信息。
4. 重新建立 GENA 订阅。
5. 查询当前播放状态。
6. 决定是否继续控制。

不能在没有确认的情况下自动重复 SetAVTransportURI。

自动恢复策略必须允许调用者配置。

---

# 21. 错误处理

## 21.1 错误分类

```dart
sealed class DlnaException implements Exception {}
```

建议包含：

```text
DlnaDiscoveryException
DlnaDeviceDescriptionException
DlnaServiceDescriptionException
DlnaNetworkException
DlnaTimeoutException
DlnaSoapException
DlnaUpnpException
DlnaUnsupportedActionException
DlnaUnsupportedMediaException
DlnaMediaServerException
DlnaSubscriptionException
DlnaSessionException
DlnaDeviceOfflineException
```

## 21.2 错误原则

必须区分：

网络错误、设备错误、协议错误、媒体错误、状态错误。

不能统一转换成：

```text
投屏失败
```

## 21.3 重试

适合重试：

- 临时网络超时。
- 设备短暂不可达。
- GENA 续订失败。

不适合盲目重试：

- Invalid Action。
- Invalid Args。
- 不支持的媒体格式。
- 参数错误。
- 不合法的 URL。

重试应采用有限次数与退避策略。

---

# 22. 安全设计

DLNA 是局域网协议，不代表天然安全。

## 22.1 SSRF 防护

设备提供的 LOCATION、控制 URL 和 SCPD URL 都属于不可信输入。

必须：

- 限制允许访问的网络范围。
- 禁止访问本机敏感服务。
- 拒绝不必要的公网跳转。
- 限制重定向次数。
- 校验最终解析地址。
- 限制响应大小。
- 限制请求超时。

## 22.2 XML 安全

必须禁用不必要的外部实体解析。

避免 XXE。

限制：

- XML 最大长度。
- XML 嵌套深度。
- 属性数量。
- 文本长度。

## 22.3 媒体服务器安全

必须：

- 使用随机资源 Token。
- 限制文件访问目录。
- 禁止任意文件路径访问。
- 防止目录穿越。
- 资源过期后拒绝访问。
- 不公开整个本地文件系统。

## 22.4 GENA 安全

Callback 请求必须验证：

- SID。
- 订阅有效性。
- SEQ。
- 请求大小。
- 允许的请求方法。

不能允许任意设备向本地 Callback Server 无限提交数据。

## 22.5 隐私

日志禁止记录：

- 完整认证 Token。
- 用户 Cookie。
- 私有播放 URL 查询参数。
- 不必要的本地文件路径。

---

# 23. 并发与资源管理

## 23.1 发现任务

同一 Discovery Manager 只允许一个活动发现任务。

重复启动应返回当前任务状态，而不是重新绑定 Socket。

## 23.2 Session 隔离

每个 Session 独立拥有：

- 播放状态。
- SOAP 操作队列。
- GENA 订阅。
- 播放监控任务。
- 媒体资源引用。

## 23.3 媒体服务器共享

HTTP Server 可以由多个 Session 共享。

但是资源必须按照 Session 引用计数或独立生命周期管理。

不能一个设备停止播放就关闭整个 HTTP Server。

## 23.4 Dispose

所有公开管理类必须提供明确的资源释放机制。

重点检查：

- Socket。
- StreamController。
- StreamSubscription。
- HTTP Server。
- HTTP Client。
- Timer。
- GENA Subscription。
- 播放命令队列。

禁止出现无法释放的后台监听任务。

---

# 24. 多平台适配

目标平台：

```text
Android
iOS
Windows
macOS
Linux
```

## 24.1 平台能力

| 平台 | SSDP | HTTP Server | GENA |
|---|---|---|---|
| Android | 支持设计 | 支持设计 | 支持设计 |
| iOS | 支持设计 | 支持设计 | 支持设计 |
| Windows | 支持设计 | 支持设计 | 支持设计 |
| macOS | 支持设计 | 支持设计 | 支持设计 |
| Linux | 支持设计 | 支持设计 | 支持设计 |

以上表示目标实现，不代表所有系统网络环境下均可无条件使用。

必须在真实系统中验证多播、防火墙、后台运行和网络权限。

## 24.2 Android

需要关注：

- INTERNET 权限。
- 局域网通信。
- Multicast Lock。
- Wi-Fi 状态。
- 后台运行限制。
- 网络切换。

如果使用 Wi-Fi Multicast Lock，应明确获取和释放时机。

不要长期持有无用锁。

## 24.3 iOS

需要关注：

- Local Network Privacy。
- NSLocalNetworkUsageDescription。
- 后台运行限制。
- 本地 HTTP Server 可访问性。
- 系统网络权限。

不能假设 iOS 后台运行期间投屏服务可以无限期维持。

## 24.4 Windows

需要关注：

- Windows Defender Firewall。
- UDP Multicast。
- TCP 入站规则。
- 网络配置文件。
- 专用网络与公用网络差异。

需要提供清晰的网络访问错误。

## 24.5 macOS

需要关注：

- App Sandbox。
- Local Network 权限。
- Firewall。
- 入站连接。
- 网络接口变化。

## 24.6 Linux

需要关注：

- UDP Multicast。
- 防火墙。
- 网卡接口。
- IPv6。
- 端口绑定。
- 系统网络管理器。

不应该要求用户为了基本 DLNA 功能安装 Avahi。

Avahi 是 Bonsoir 的 Linux mDNS 后端要求，但 SSDP 应由本包自己的 UDP 实现负责。

## 24.7 Bonsoir

依赖：

```yaml
bonsoir: ^7.1.6
```

用途：

- mDNS 服务发现。
- DNS-SD 服务解析。
- 辅助识别支持 mDNS 的设备。

不负责：

- SSDP。
- DLNA Renderer 认证。
- SOAP。
- GENA。
- 媒体投送。

Bonsoir 不能作为 DLNA 设备发现的唯一实现。

---

# 25. 日志与诊断

## 25.1 日志分类

```text
Discovery
SSDP
DeviceDescription
SOAP
GENA
MediaSelection
MediaServer
Playback
Session
Network
Compatibility
```

## 25.2 日志等级

Debug：

- SSDP 原始响应。
- 设备描述解析过程。
- SOAP Action。
- 媒体资源选择结果。

Info：

- 设备发现。
- 设备上线。
- 设备连接。
- 开始播放。
- 停止播放。

Warning：

- 设备能力不完整。
- GENA 不可用。
- 设备响应异常。
- 媒体格式不确定。

Error：

- 网络异常。
- SOAP Fault。
- 媒体服务器失败。
- Session 失效。

## 25.3 诊断信息

建议公开诊断快照：

```dart
class DlnaDiagnostics {
  final int discoveredDeviceCount;

  final int activeSessionCount;

  final bool mediaServerRunning;

  final bool discoveryRunning;

  final DateTime capturedAt;
}
```

不要把敏感网络信息直接暴露到普通日志。

---

# 26. 测试规范

## 26.1 单元测试

必须覆盖：

SSDP：

- M-SEARCH 解析。
- NOTIFY 解析。
- Header 大小写。
- USN 提取。
- CACHE-CONTROL。
- 错误数据包。

XML：

- Device Description。
- Service Description。
- SOAP Response。
- SOAP Fault。
- DIDL-Lite。

媒体：

- ProtocolInfo。
- MIME Type。
- DLNA 参数。
- Range 请求。
- Content-Range。

## 26.2 集成测试

需要模拟：

```text
SSDP Server
UPnP Renderer
SOAP Endpoint
GENA Endpoint
HTTP Media Server
```

至少验证完整流程：

```text
发现设备
   ↓
获取描述
   ↓
解析服务
   ↓
连接设备
   ↓
设置媒体
   ↓
播放
   ↓
暂停
   ↓
继续
   ↓
跳转
   ↓
停止
   ↓
释放 Session
```

## 26.3 真实设备测试

至少准备：

- 一台 Android TV。
- 一台支持 DLNA 的智能电视。
- 一台 Windows 设备。
- 一台 macOS 设备。
- 一台 Linux 设备。

不同品牌的 Renderer 必须进行兼容性测试。

## 26.4 异常测试

必须验证：

- 设备突然断电。
- 设备 IP 改变。
- Wi-Fi 断开。
- 路由器重启。
- SSDP 无响应。
- SOAP 超时。
- GENA 续订失败。
- 媒体 URL 失效。
- HTTP Range 不支持。
- 电视不支持视频编码。
- 电视拒绝播放。
- 本地 HTTP Server 端口被占用。

---

# 27. 开发实施阶段

这是整个项目最重要的执行部分。

必须按照阶段推进。

不能跳过基础协议直接开发 UI。

## Phase 0：项目初始化与架构确认

目标：

建立 Package 基础结构。

任务：

1. 创建 package。
2. 配置 pubspec。
3. 配置 analysis_options。
4. 建立公开入口。
5. 建立 Domain / Application / Infrastructure。
6. 定义基础错误体系。
7. 定义网络依赖抽象。
8. 定义测试结构。
9. 明确与 media_core 其他 Package 的依赖关系。

交付：

- Package 基础结构。
- 依赖说明。
- 核心接口。
- 架构文档。

验收：

- flutter analyze 通过。
- flutter test 通过。
- 无循环依赖。
- 领域层没有 Flutter 插件依赖。

## Phase 1：SSDP 设备发现

目标：

实现真正的 DLNA 设备发现。

任务：

1. 实现 UDP Socket。
2. 实现 Multicast。
3. 实现 M-SEARCH。
4. 实现 SSDP Parser。
5. 实现 NOTIFY Listener。
6. 实现设备去重。
7. 实现设备缓存。
8. 实现设备离线检测。
9. 实现发现状态 Stream。
10. 实现发现生命周期管理。

交付：

- SsdpClient。
- SsdpParser。
- DlnaDiscoveryManager。
- DlnaDeviceRegistry。

验收：

- 可以发现真实 DLNA Renderer。
- 多设备可以同时发现。
- 同一设备不会重复添加。
- 可以处理设备上线和离线。
- 可以停止发现并释放 Socket。

## Phase 2：设备描述和服务解析

目标：

将 SSDP 发现结果转换为完整设备模型。

任务：

1. 获取 LOCATION。
2. 实现 Device Description XML 解析。
3. 解析 UDN。
4. 解析 FriendlyName。
5. 解析 Manufacturer。
6. 解析 ModelName。
7. 解析 DeviceType。
8. 解析 ServiceList。
9. 解析 URLBase。
10. 获取 SCPD。
11. 解析 Action。
12. 解析 StateVariable。
13. 生成 DlnaDevice。

交付：

- DeviceDescriptionParser。
- ServiceDescriptionParser。
- DlnaService。
- DlnaDevice。

验收：

- 可以解析主流设备描述。
- 支持 Namespace。
- 支持多个服务。
- 支持 URL 相对路径。
- 不规范设备描述不会导致整个发现服务崩溃。

## Phase 3：SOAP 控制基础设施

目标：

实现 UPnP 标准控制通信。

任务：

1. SOAP Envelope 构建。
2. Action 参数构建。
3. SOAPAction Header。
4. HTTP POST。
5. XML Response 解析。
6. SOAP Fault 解析。
7. UPnP Error Mapping。
8. 请求超时。
9. 请求取消。
10. Action 能力检查。

交付：

- SoapClient。
- SoapRequestBuilder。
- SoapResponseParser。
- SoapFaultParser。

验收：

- 可以与真实 Renderer 通信。
- 能正确执行标准 Action。
- 能解析 UPnP 错误。
- 能处理超时和断线。
- XML 特殊字符不会破坏请求。

## Phase 4：DLNA 媒体能力协商

目标：

让系统知道电视可以播放什么。

任务：

1. 解析 GetProtocolInfo。
2. 解析 Sink ProtocolInfo。
3. 解析 DLNA.ORG_PN。
4. 解析 DLNA.ORG_OP。
5. 解析 DLNA.ORG_CI。
6. 建立媒体格式模型。
7. 建立资源评分机制。
8. 实现媒体资源选择。
9. 处理未知设备能力。
10. 输出不支持原因。

交付：

- DlnaMediaCapability。
- DlnaMediaSelector。
- ProtocolInfoParser。
- DlnaMediaSelection。

验收：

- 能识别设备支持的常见媒体格式。
- 能根据能力选择资源。
- 不支持的格式能够明确报错。
- 不依赖硬编码电视品牌判断。

## Phase 5：HTTP 媒体服务器

目标：

让 Renderer 能够访问 PureLive 本地媒体。

任务：

1. HTTP Server 生命周期。
2. 动态端口。
3. 局域网地址选择。
4. 资源注册。
5. 资源 Token。
6. GET。
7. HEAD。
8. Range。
9. Content-Length。
10. Content-Range。
11. MIME Type。
12. 文件 Stream。
13. 请求取消。
14. 资源过期清理。
15. 多设备并发访问。

交付：

- MediaHttpServer。
- MediaHttpHandler。
- MediaResourceBuilder。
- MediaHttpRange。

验收：

- 电视可以访问本地文件。
- 支持 Range 请求。
- 大文件不会整体加载进内存。
- 多个设备可以同时访问。
- 资源释放不会影响其他 Session。

## Phase 6：投屏播放控制

目标：

实现完整的基础 DLNA 投屏功能。

任务：

1. 建立 Session。
2. 设置媒体 URI。
3. 构建 DIDL-Lite。
4. SetAVTransportURI。
5. Play。
6. Pause。
7. Stop。
8. Seek。
9. GetTransportInfo。
10. GetPositionInfo。
11. 获取当前媒体。
12. 错误处理。
13. 操作队列。
14. Session Dispose。

交付：

- DlnaSessionManager。
- DlnaPlaybackController。
- AvTransportService。
- DlnaSession。

验收：

- 可以向真实电视投送视频。
- 可以播放、暂停、停止。
- 支持设备能力允许的 Seek。
- 播放操作顺序正确。
- 设备拒绝播放时能够返回具体错误。

## Phase 7：GENA 状态订阅

目标：

实现电视主动状态同步。

任务：

1. Callback HTTP Server。
2. SUBSCRIBE。
3. SID 管理。
4. TIMEOUT 管理。
5. NOTIFY。
6. SEQ 去重。
7. PropertySet 解析。
8. 订阅续订。
9. UNSUBSCRIBE。
10. 轮询降级。
11. 设备离线清理。

交付：

- GenaSubscriber。
- GenaCallbackServer。
- GenaMessageParser。
- GenaSubscription。

验收：

- 可以收到真实设备状态通知。
- 可以自动续订。
- 设备断开后可以清理。
- GENA 失败可以回退轮询。
- 不会出现过期订阅泄漏。

## Phase 8：RenderingControl 与多设备管理

目标：

完善投屏体验。

任务：

1. 获取音量。
2. 设置音量。
3. 获取静音。
4. 设置静音。
5. 多 Renderer 管理。
6. 多 Session 隔离。
7. 播放状态独立。
8. 设备切换。
9. 设备断线恢复。
10. 资源共享管理。

交付：

- RenderingControlService。
- DlnaConnectionManager。
- 多设备 Session 管理。

验收：

- 多设备可以独立播放。
- 音量控制符合设备能力。
- 设备断线不会影响其他设备。
- 媒体服务器生命周期正确。

## Phase 9：设备兼容性

目标：

解决不同电视厂商的实现差异。

任务：

1. 建立兼容性配置。
2. 识别厂商和型号。
3. 处理不同服务版本。
4. 处理 InstanceID 差异。
5. 处理 SOAP Header 差异。
6. 处理 DIDL-Lite 差异。
7. 处理媒体 MIME Type 差异。
8. 处理 Seek 差异。
9. 处理状态报告差异。
10. 建立兼容性测试集合。

交付：

- DeviceCompatibilityRegistry。
- DeviceCompatibilityProfile。
- 厂商兼容配置。

验收：

- 标准设备不依赖特殊兼容配置。
- 厂商差异不会污染核心协议代码。
- 新增兼容策略不需要修改领域模型。

## Phase 10：稳定性与正式发布

目标：

达到 media_core 正式 Package 发布标准。

任务：

1. 多平台测试。
2. 内存泄漏测试。
3. Socket 生命周期测试。
4. 网络切换测试。
5. 并发测试。
6. 长时间播放测试。
7. 错误恢复测试。
8. 文档完善。
9. API 审查。
10. 版本发布。

交付：

- README。
- API 文档。
- TECHNICAL_DESIGN。
- CHANGELOG。
- 测试报告。
- 正式 Release。

验收：

- 所有目标平台构建通过。
- 核心测试通过。
- 无已知严重资源泄漏。
- 长时间播放稳定。
- 设备断线可恢复。
- 对外 API 稳定。

---

# 28. 公开 API 设计

公开 API 必须保持简单。

建议：

```dart
class DlnaClient {
  Future<void> initialize();

  Future<void> startDiscovery();

  Future<void> stopDiscovery();

  Stream<List<DlnaDevice>> get devices;

  Future<DlnaSession> connect(DlnaDevice device);

  Future<void> dispose();
}
```

Session：

```dart
abstract interface class DlnaSession {
  DlnaDevice get device;

  DlnaConnectionState get connectionState;

  DlnaPlaybackState get playbackState;

  Stream<DlnaPlaybackState> get playbackStateStream;

  Future<void> setMedia(DlnaMedia media);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> setVolume(int volume);

  Future<void> setMute(bool muted);

  Future<void> disconnect();
}
```

以上为目标接口示意，实际实现必须根据各功能阶段的能力逐步开放。

不支持的 Action 应通过能力检查和明确错误返回。

---

# 29. 性能要求

## 29.1 设备发现

- 搜索过程不能阻塞 UI。
- 多设备响应不能串行等待。
- 设备描述获取应有限并发。
- 同一设备描述请求应去重。
- 搜索停止后立即释放无用任务。

## 29.2 播放

- SOAP 操作必须有超时。
- 播放控制不能阻塞 UI。
- 不允许重复创建 HTTP Server。
- 媒体数据使用 Stream。
- 不允许完整视频进入内存缓存。

## 29.3 状态同步

- GENA 优先。
- 轮询必须可配置。
- 多 Session 互不干扰。
- 不允许无限轮询。
- 不允许状态事件无限积压。

---

# 30. AI 开发规范

本节是强制规范。

所有 AI 编码任务必须遵守。

## 30.1 开发前

修改任何文件前：

1. 阅读当前 Package 架构。
2. 阅读现有接口。
3. 检查 media_core 现有依赖。
4. 检查是否存在重复实现。
5. 明确当前任务所属 Phase。
6. 明确输入和输出。
7. 明确验收标准。

禁止未经审查直接新增一套通用网络基础设施。

## 30.2 分阶段开发

必须遵循：

```text
先设计
  ↓
再确定接口
  ↓
再实现基础设施
  ↓
再实现应用逻辑
  ↓
再测试
  ↓
再进入下一阶段
```

不允许一次性生成全部文件。

## 30.3 架构约束

Domain：

- 不依赖 Flutter。
- 不依赖 Bonsoir。
- 不依赖 UDP Socket。
- 不依赖具体 HTTP Client。
- 不负责设备发现。

Application：

- 负责用例编排。
- 负责生命周期。
- 负责会话管理。
- 不直接处理 XML 字符串。

Infrastructure：

- 负责网络。
- 负责协议解析。
- 负责 XML。
- 负责 SOAP。
- 负责 GENA。
- 负责 HTTP Server。

## 30.4 禁止事项

禁止：

- 将所有功能放入 DlnaClient。
- 将所有协议放入一个 Service。
- 将设备名称作为唯一 ID。
- 将设备 IP 作为唯一 ID。
- 用 Bonsoir 替代 SSDP。
- 用字符串切割解析 XML。
- 将 SOAP 请求直接写入 UI。
- 将媒体文件整体读入内存。
- 忽略设备能力。
- 将所有错误转换成 Exception("failed")。
- 使用全局单例保存活动 Session。
- 在 dispose 后继续发送网络请求。
- 为了兼容单个设备污染核心模型。

## 30.5 代码质量

- 使用明确的类型。
- 优先不可变模型。
- 使用异步 API。
- 所有资源具有明确生命周期。
- 避免无意义抽象。
- 不创建没有实际用途的空接口。
- 避免超大类。
- 使用一致的错误类型。
- 为复杂协议解析编写测试。
- 对外 API 必须有文档注释。

## 30.6 注释规范

代码注释使用英文。

设计文档和开发文档使用中文。

协议常量保留标准英文名称。

## 30.7 修改文件规范

每次任务：

1. 先说明当前阶段。
2. 说明要修改的文件。
3. 说明设计决策。
4. 再批量实施。
5. 完成后执行格式化。
6. 执行 Analyze。
7. 执行相关测试。
8. 汇报实际完成内容。

不得声称没有执行过的测试已经通过。

---

# 31. 后续扩展

## 31.1 转码系统

后续可以接入：

```text
media_core_cast_dlna
        │
        ▼
DlnaMediaSelector
        │
        ▼
Transcoding Resolver
        │
        ▼
media_core
        │
        ▼
FFmpeg / Media Engine
        │
        ▼
Compatible Media Stream
```

转码不属于本包的核心协议实现。

## 31.2 HLS 投送

支持：

- 公网 HLS。
- 本地 HLS。
- HLS 代理。
- 直播清单。
- 媒体分片。

必须注意电视能否访问清单及其所有分片。

## 31.3 字幕

后续可支持：

- 外部 SRT。
- WebVTT。
- DIDL-Lite 字幕资源。
- 设备字幕能力检测。

不同 Renderer 的字幕支持差异很大。

不能将字幕能力作为基础投屏必需条件。

## 31.4 播放队列

可增加：

```text
DlnaPlaybackQueue
```

管理：

- 当前媒体。
- 下一媒体。
- 上一媒体。
- 自动播放下一项。
- 播放失败跳过。

是否支持 SetNextAVTransportURI 由设备能力决定。

---

# 32. 参考资料

## UPnP

UPnP Device Architecture 1.1：

https://openconnectivity.org/upnp-specs/UPnP-arch-DeviceArchitecture-v1.1.pdf

ISO/IEC 29341-1-1：

https://www.iso.org/standard/57494.html

## Bonsoir

Pub.dev：

https://pub.dev/packages/bonsoir

Documentation：

https://bonsoir.skyost.eu/docs/

GitHub：

https://github.com/Skyost/Bonsoir

## DLNA

DLNA 官方：

https://www.dlna.org/

## Dart

Dart UDP Socket：

https://api.dart.dev/dart-io/RawDatagramSocket-class.html

Dart HTTP Server：

https://api.dart.dev/dart-io/HttpServer-class.html

Dart HTTP Client：

https://api.dart.dev/dart-io/HttpClient-class.html

---

# 33. 最终实施要求

media_core_cast_dlna 必须遵循以下最终原则：

1. SSDP 是 DLNA 设备发现的主要机制。
2. Bonsoir 只能作为辅助 mDNS 发现工具。
3. UPnP Device Description 是设备能力解析基础。
4. SOAP 是设备控制基础。
5. GENA 是状态同步机制。
6. HTTP Media Server 是本地媒体投送基础。
7. DLNA Profile 和 ProtocolInfo 是媒体兼容性基础。
8. 设备能力必须动态检测。
9. 所有 Session 必须独立管理。
10. 所有网络资源必须有明确生命周期。
11. 厂商兼容逻辑必须独立。
12. 不得依赖本地播放器完成远程 Renderer 控制。
13. 不得把 Google Cast、AirPlay 等其他协议塞入本包。
14. 必须支持 media_core 规定的多平台目标。
15. 必须按 Phase 逐步开发和验收。

最终目标：

让 media_core_cast_dlna 成为一个独立、稳定、可扩展、跨平台的 DLNA / UPnP 投屏协议实现，为 PureLive 提供可靠的局域网媒体投送能力。
