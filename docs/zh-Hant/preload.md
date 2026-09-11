# preload 模塊

> 媒體預載:基於優先級的預載任務調度、預熱與生命週期管理(以源為 key)。

## 模塊職責

- 維護預載任務表,按優先級排序出隊執行。
- 對外暴露指標流與任務生命週期操作。

## 核心 API

| API | 說明 |
| --- | --- |
| `PreloadManager` | 任務表管理者:`metrics` 流(BehaviorSubject)、`add(PreloadRequest)`、`next()`、`complete(task)`、`fail(task)` |
| `PreloadScheduler` | 維護按優先級排序的任務列表;`add` 置為 queued 並按優先級降序重排,`next()` 彈出隊首 |
| `PreloadPriority` | 枚舉:low / normal / high / critical |
| `PreloadRequest` / `PreloadTask` | sourceId + 優先級的請求 / 帶生命週期轉換的可運行任務 |
| `PreloadState` | pending/loading/completed/failed/cancelled 旗標,`queued()/start()` 轉換輔助 |
| `PreloadMetrics` / `PreloadContext` | 計數器 / 上下文對象 |

## 設計說明

- 行為上限(最大預載數、warmup、後台預載)由 `policy` 模塊的 `PreloadPolicy` 提供。

## 依賴

- 內部:`identity`(SourceId)
- 外部:`rxdart`、`equatable`
