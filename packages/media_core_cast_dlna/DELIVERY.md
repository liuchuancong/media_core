# media_core_cast_dlna 交付报告（TECHNICAL_DESIGN.md §33 合规审计）

- 日期：2026-11-01
- 版本：0.8.0
- 测试：181 个全部通过；`dart analyze` 零问题；工作区 kareki 基线通过

## §33 最终实施要求逐条核验（15/15 通过）

| # | 要求 | 证据 |
|---|---|---|
| 1 | SSDP 是发现的主要机制 | `SsdpClient`（多目标 M-SEARCH/NOTIFY/max-age 到期）；Bonsoir 仅为 `MDnsServiceHint` 辅助通道 |
| 2 | Bonsoir 只作辅助 | `BonsoirDiscoveryChannel` 仅发提示流，无描述解析、无控制路径 |
| 3 | Device Description 是能力解析基础 | `DeviceDescriptionParser`（URLBase/嵌套设备/SCPD） |
| 4 | SOAP 是控制基础 | `SoapClient` + `SoapRequestBuilder`（全部 AVT/RC 动作） |
| 5 | GENA 是状态同步机制 | `GenaSubscriber` + `GenaCallbackServer`，轮询保底（§14.7） |
| 6 | HTTP Media Server 是本地投送基础 | `MediaHttpServer`（Token/Range/流式） |
| 7 | DLNA Profile/ProtocolInfo 是兼容基础 | `MediaProtocolInfo`/`DlnaMediaCapability`/`DlnaMediaSelector` |
| 8 | 设备能力动态检测 | `DlnaCapabilityResolver` 走 GetProtocolInfo；无品牌硬编码 |
| 9 | Session 独立管理 | `DlnaSessionManager`：每设备一会话、独立队列/监控/订阅 |
| 10 | 网络资源明确生命周期 | 全部 `dispose()` 链路有压力测试钉住（30 次会话/50 次服务器循环） |
| 11 | 厂商兼容逻辑独立 | `DeviceCompatibilityRegistry`/`Profile`；领域与协议层零感知 |
| 12 | 不依赖本地播放器控制 Renderer | 无 media_kit/fvp/ijk 依赖（grep = 0） |
| 13 | 不塞入其他投屏协议 | 无 Google Cast/AirPlay/Miracast 痕迹（grep = 0） |
| 14 | 支持规定多平台 | 纯 Dart（`RawDatagramSocket`+`HttpClient`+Bonsoir）；平台权限文档化（README） |
| 15 | 按 Phase 逐步开发验收 | CHANGELOG 0.2～0.8 与 Phase 0～9 一一对应；§30.7 流程逐轮执行 |

## §30 架构约束核验

- Domain 层零 Flutter/Bonsoir/Socket/HTTP 依赖（grep = 0，唯一命中为文档注释）
- lib 无 print（诊断统一走 `DlnaLog`，默认静默）
- 无 TODO/FIXME 残留
- 59 个 lib 文件与入口导出 1:1，无内部泄漏、无悬挂导出

## §10 Phase 10 代码侧验收核验

| 任务 | 状态 |
|---|---|
| 多平台构建 | 代码级 ✅（Windows 实测构建+测试通过；其余平台纯 Dart 无平台代码，待真机） |
| 内存/socket 泄漏 | ✅ 生命周期压力测试（30 次会话/50 次服务器/30 次 SSDP 循环） |
| 长时间播放 | ◐ 代码侧 20ms×250 tick 监控模拟通过；真机长播待测 |
| 错误恢复 | ✅ 恢复循环/降级/耗尽进 Failed 全覆盖 |
| 并发 | ✅ 30 设备脉冲 + 6 命令竞态断开 |
| 文档 | ✅ README/CHANGELOG/TECHNICAL_DESIGN 交付状态对齐 |
| API 审查 | ✅ 导出 1:1，无泄漏 |

## 待真机矩阵（Phase 10 剩余）

Android TV / 智能电视 / Windows / macOS / Linux 各一台：长时间播放、断网恢复、厂商怪癖收集（注册进 `DeviceCompatibilityRegistry`）、正式 Release。
