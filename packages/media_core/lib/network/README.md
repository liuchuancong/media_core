# network 模塊

> 網絡抽象:連通性狀態/條件/類型/質量建模、性能指標與請求/響應執行;監控委託給平台適配層。

## 模塊職責

- 提供平台無關的網絡模型(狀態、條件、類型、質量)與性能指標。
- 定義可注入的請求執行器接口;自身不測帶寬、不 ping、不做 IO。

## 核心 API

| API | 說明 |
| --- | --- |
| `NetworkManager` | 主入口:持有 `NetworkMonitor`,暴露 `state/condition/metrics` 及其流、`start/stop`、`request(NetworkRequest)` |
| `NetworkMonitor` / `BaseNetworkMonitor` | 抽象監控接口 + 廣播流基類;子類覆寫 `onStart/onStop` 並以保護方法 `updateState/updateCondition/updateMetrics` 推送更新 |
| `NetworkCondition` | freezed:connected、type、quality、上下行帶寬、latency、metered、expensive;擴展 `isAvailable/isFast/hasLatency` |
| `NetworkState` | connected/type/quality/metered/expensive/updatedAt |
| `NetworkMetrics` | latency min/avg/max、吞吐、請求/字節計數;`failureRate`、`hasHighFailureRate`、`isHealthy` |
| `NetworkRequest` / `NetworkResponse` | 請求(uri、method、`SourceHeaders`、body、超時、maxRetries、cacheable)與響應(statusCode、data、headers、duration、fromCache、`isSuccess`) |
| `NetworkType` / `NetworkQuality` | 枚舉:unknown/none/ethernet/wifi/mobile/bluetooth/vpn/other;unknown/unavailable/poor/fair/good/excellent(`isUsable/isStable/score 0–5`) |

## 設計說明

- 純數據模型層;http/dio/平台適配通過注入的 executor 接入。

## 依賴

- 內部:`source`(SourceHeaders)
- 外部:`freezed` / `freezed_annotation`
