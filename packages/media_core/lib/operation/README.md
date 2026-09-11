# operation 模塊

> 高層異步/業務操作:把 open/play/seek/recover 等操作建模為帶嚴格狀態轉換校驗的不可變生命週期記錄,附註冊表、響應式追蹤器、取消令牌與超時策略。

## 模塊職責

- 以值對象方式描述操作(不做執行):`Operation` 記錄 id、類型、狀態、上下文與時間戳。
- 提供執行側控制(取消令牌)、策略(超時)與觀察(Registry / Tracker)。

## 核心 API

| API | 說明 |
| --- | --- |
| `Operation` | 不可變生命週期記錄;`start()/complete()/fail()/cancel()` 返回新實例,非法轉換拋 `StateError`;不含執行邏輯 |
| `OperationState` | 值對象(非 enum):created/running/completed/failed/cancelled + `custom()`;顯式轉換圖,終態封閉 |
| `OperationType` | 值對象,23 種內置類型(open、play、pause、stop、seek、close、initialize、dispose、prepare、load、reload、速率/音量/靜音設置、全屏/畫中畫進出、錄製開始/停止、recover、fallback、retry)+ 分類 getter(isPlaybackOperation 等) |
| `OperationContext` | 豐富關聯上下文(全部 7 種 id、lineId、quality、uri、platform、backend、adapter、參數/metadata);流式 `withX()/withoutX()`;完整 JSON 往返 |
| `OperationCancelToken` | 執行側取消控制:`cancel([reason])`、`cancelledFuture`、`onCancel` 流、`throwIfCancelled()`、`run/runChecked`、層級 `child()/fork()`(僅父→子傳播);拋 `OperationCancelledException`;不直接修改 OperationState |
| `OperationTimeout` | 時長+啟用開關的策略:`deadlineFor`、`remainingFor`、`isExpired`(終態操作永不超時) |
| `OperationRegistry` | 註冊操作的權威集合:register/update/remove、按狀態查詢;不執行、不取消 |
| `OperationTracker` | 響應式觀察:每 id 最新快照 + 有界歷史(默認 1000),BehaviorSubject 當前流 + PublishSubject 操作流,`markStarted/Completed/Failed/Cancelled` 輔助與歷史查詢 |

## 設計說明

- 最大的模塊(約 3400 行),職責切分在文檔中反覆強調:Operation(模型)/ CancelToken(執行)/ Timeout(策略)/ Registry(所有權)/ Tracker(觀察);執行、調度、重試、恢復屬於更高層。
- 全程使用 `clock`,保證可測試。

## 依賴

- 內部:`identity`
- 外部:`rxdart`、`clock`、`equatable`
