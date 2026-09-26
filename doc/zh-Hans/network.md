# network 模块

> 网络抽象：连通性状态/条件/类型/质量建模、性能指标与请求/响应执行；监控委托给平台适配层。

## 模块职责

- 提供平台无关的网络模型（状态、条件、类型、质量）与性能指标。
- 定义可注入的请求执行器接口；自身不测带宽、不 ping、不做 IO。

## 核心 API

| API | 说明 |
| --- | --- |
| `NetworkManager` | 主入口：持有 `NetworkMonitor`，暴露 `state/condition/metrics` 及其流、`start/stop`、`request(NetworkRequest)` |
| `NetworkMonitor` / `BaseNetworkMonitor` | 抽象监控接口 + 广播流基类；子类覆写 `onStart/onStop` 并以保护方法 `updateState/updateCondition/updateMetrics` 推送更新 |
| `NetworkCondition` | freezed：connected、type、quality、上下行带宽、latency、metered、expensive；扩展 `isAvailable/isFast/hasLatency` |
| `NetworkState` | connected/type/quality/metered/expensive/updatedAt |
| `NetworkMetrics` | latency min/avg/max、吞吐、请求/字节计数；`failureRate`、`hasHighFailureRate`、`isHealthy` |
| `NetworkRequest` / `NetworkResponse` | 请求（uri、method、`SourceHeaders`、body、超时、maxRetries、cacheable）与响应（statusCode、data、headers、duration、fromCache、`isSuccess`） |
| `NetworkType` / `NetworkQuality` | 枚举：unknown/none/ethernet/wifi/mobile/bluetooth/vpn/other；unknown/unavailable/poor/fair/good/excellent（`isUsable/isStable/score 0–5`） |

## 设计说明

- 纯数据模型层；http/dio/平台适配通过注入的 executor 接入。

## 依赖

- 内部：`source`（SourceHeaders）
- 外部：`freezed` / `freezed_annotation`
