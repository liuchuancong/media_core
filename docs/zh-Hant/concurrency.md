# concurrency 模塊

> 可複用的異步並發原語:鎖、互斥量、信號量、並發上限與串行執行器,以及按 key 共享它們的中心管理器。

## 模塊職責

- 提供純基礎設施級的並發控制原語,不含任何業務邏輯。
- 通過 `ConcurrencyManager` 按 `ConcurrencyKey` 跨模塊共享同一把鎖/信號量/串行器。

## 核心 API

| API | 說明 |
| --- | --- |
| `ConcurrencyManager` | 中心註冊表:按 key 取得 `withLock`、mutex、limit 與串行執行器 |
| `AsyncLock` | 單持有者異步鎖,附 `synchronized()` 輔助 |
| `Mutex` | 傳統 acquire/release 互斥,附 `protect()` |
| `AsyncSemaphore` | 許可計數的並發限制器,附 `withPermit()` |
| `ConcurrencyLimit` | 基於 `package:pool` 的並發桶:maxConcurrent、許可獲取、受守護動作 |
| `SerialExecutor` | FIFO 異步任務隊列,一次執行一個 |
| `ExclusiveTask` | 獨佔式任務:鏈接在上個任務完成之後執行(適合 init、換源) |
| `ConcurrencyKey` | 領域無關的資源標識(`scope:name`),由調用方擁有 |

## 設計說明

- 文檔註釋明確區分 lock / mutex / limit / serial executor 的適用場景。
- 資源 key 由調用方定義,本模塊不感知語義。

## 依賴

- 外部:`package:pool`
