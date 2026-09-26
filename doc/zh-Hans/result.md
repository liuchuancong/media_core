# result 模块

> 统一、不可变、基于值的结果类型：同步 `Result`、进行中的 `AsyncResult` 与操作级 `OperationResult`。

## 模块职责

- 提供经典的 success/failure 值结果。
- 把「异步进行中」状态与「最终结果」刻意分开建模。

## 核心 API

| API | 说明 |
| --- | --- |
| `Result<T>` | sealed：`ResultSuccess<T>` / `ResultFailure<T>` |
| `AsyncResult<T>` / `AsyncResultStatus` | 异步生命周期（loading/running）；与终态结果分离是刻意设计 |
| `OperationResult<T>` | 操作级结果；不含重试/降级策略（属其他层） |
| `ResultError` | 仅错误载荷；分类/恢复策略留在 error 层 |
| `ResultStatus` | 终态状态值；刻意排除异步中间态 |

## 设计说明

- 一切不可变且 Equatable；异步中间态与终态的分离是本模块核心设计点。

## 依赖

- 内部：`identity`（RequestId、GenerationId）、`error`（PlayerFailure 等）
