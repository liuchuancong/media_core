# result 模塊

> 統一、不可變、基於值的結果類型:同步 `Result`、進行中的 `AsyncResult` 與操作級 `OperationResult`。

## 模塊職責

- 提供經典的 success/failure 值結果。
- 把「異步進行中」狀態與「最終結果」刻意分開建模。

## 核心 API

| API | 說明 |
| --- | --- |
| `Result<T>` | sealed:`ResultSuccess<T>` / `ResultFailure<T>` |
| `AsyncResult<T>` / `AsyncResultStatus` | 異步生命週期(loading/running);與終態結果分離是刻意設計 |
| `OperationResult<T>` | 操作級結果;不含重試/降級策略(屬其他層) |
| `ResultError` | 僅錯誤載荷;分類/恢復策略留在 error 層 |
| `ResultStatus` | 終態狀態值;刻意排除異步中間態 |

## 設計說明

- 一切不可變且 Equatable;異步中間態與終態的分離是本模塊核心設計點。

## 依賴

- 內部:`identity`(RequestId、GenerationId)、`error`(PlayerFailure 等)
