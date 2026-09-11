# recovery 模塊

> 播放恢復:失敗後決定並調度恢復動作(重試/重啟/重新初始化/停止)。

## 模塊職責

- 以 sealed `RecoveryAction` 表示決策值(非執行請求)。
- `RecoveryManager` 啟動恢復、跟蹤上下文與嘗試次數、調度重試、完成或耗盡。
- `RetryScheduler` 只管重試時序的計算與執行。

## 核心 API

| API | 說明 |
| --- | --- |
| `RecoveryAction` | sealed 決策:`None/Retry/Restart/Reinitialize/Stop`(僅是值,不是執行請求) |
| `RecoveryReason` | sealed 原因:Unknown/Network/Timeout/Decoder/Renderer/Source/Initialization/Interrupted/Resource |
| `RecoveryManager` | 啟動恢復、跟蹤 context/attempts、調度重試、complete/exhaust;暴露 `RecoverySnapshot` |
| `RetryScheduler` / `RetryState` | 只管重試時序 / 重試序號與嘗試計數 |
| `RecoveryState` | 生命週期:idle → … → complete/exhaust(見類文檔流程) |
| `RecoveryContext` / `RecoverySnapshot` | 不可變身份/診斷數據與只讀狀態視圖 |

## 設計說明

- 策略(action)與執行(manager)與診斷(reason/snapshot)嚴格分離。

## 依賴

- 內部:`identity`(SourceId、RequestId、OperationId、GenerationId)
