# task 模塊

> 可調度任務執行:任務值對象、優先級隊列、調度器與擁有生命週期的管理器。

## 模塊職責

- 以 `PlayerTask`(freezed)描述可調度的工作。
- `TaskScheduler` 做中立的生命週期推進(僅 queued → running);`TaskManager` 擁有任務生命週期與執行槽位。
- 提供協作式取消令牌。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerTask` | 可調度工作的描述(freezed) |
| `TaskManager` | 擁有生命週期與執行槽位;拋 `TaskExecutionFailure`(保留失敗任務 + 錯誤 + 棧)與釋放錯誤 |
| `TaskScheduler` | 除 `queued → running` 外保持中立;不擁有註冊表/取消 |
| `TaskQueue` | 不可變隊列(所有變更返回新隊列);確定性排序:優先級 → 創建時間 → `TaskId`;`TaskQueueResult` 用於移除操作 |
| `TaskCancelToken` / `TaskCancelledException` | 協作式取消(active → cancelled/disposed)與異常 |
| `TaskId` / `TaskType` / `TaskPriority` / `TaskState` | 小型 Comparable id(防 id 類型混用)/ 值對象類型(非 enum,便於適配器擴展)/ 優先級 / 終態封閉的狀態 |
| `TaskContext` | freezed 執行上下文:重試信息 + JSON 兼容 metadata;`task_json_converters.dart` 提供 json_serializable 轉換器 |

## 依賴

- 內部:`operation`(operation_context.dart)、`identity`(各類 id 與轉換器)
