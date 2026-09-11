# fallback 模塊

> 降級機制:在三個維度(後端實現、播放線路 URL、清晰度檔位)上協調退化/重試生命週期。

## 模塊職責

- 以三套相同的狀態機模式分別管理後端、線路、清晰度的候選遍歷。
- 由 `FallbackManager` 持有活動上下文,把具體選擇委託給三個協調器。
- 提供語義化的降級原因與關聯 id。

## 核心 API

| API | 說明 |
| --- | --- |
| `BackendFallback` / `BackendFallbackState` | 後端 id 候選遍歷:`start/next/markFailed/complete/exhaust/reset` |
| `LineFallback` / `LineFallbackState` | 播放線路 id 的同模式遍歷 |
| `QualityFallback` / `QualityFallbackState` | 清晰度 id 的同模式遍歷 |
| `FallbackManager` | 持有活動 `FallbackContext`,提供 `success` / `failure` 結果工廠;委託三個協調器 |
| `FallbackContext` | 降級請求的原因 + 關聯 id(operationId/requestId/sourceId/generationId)+ message/metadata |
| `FallbackReason` | sealed 原因:unknown/backend/line/quality/network/decoder/renderer/timeout;僅描述,不決定策略 |
| `FallbackResult` | 成功攜帶 target;失敗攜帶診斷信息 |

## 設計說明

- 狀態為不可變 Equatable,支持 `toMap`/`fromMap`;被選中的候選會從候選集中移除。
- `exhausted` 意為「一次失敗後再無候選」——僅選中最後一個候選並不算耗盡。
- 協調器不創建後端、不打開媒體、不控制播放。

## 依賴

- 內部:`identity`
