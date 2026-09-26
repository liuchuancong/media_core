# state_machine 模塊

> 通用的、領域無關的狀態機基礎設施:狀態、事件、轉換與編排。

## 模塊職責

- 提供泛型狀態機(狀態 + 事件 + 轉換定義 + 守衛)。
- 機器只管轉換執行;控制器圍繞機器做運行時編排(生命週期、隊列)。

## 核心 API

| API | 說明 |
| --- | --- |
| `StateMachine<S>` | 只擁有轉換執行;無持久化/生命週期/重試 |
| `StateMachineController<S>` | 運行時編排:生命週期與隊列;不替換機器、不實現重試策略 |
| `StateMachineState` | 不可變狀態契約;無副作用 |
| `StateMachineEvent` | 事件值對象 |
| `StateTransition<S>` / `StateTransitionGuard<S>` | 轉換定義 / 守衛 typedef |
| `StateTransitionResult<S>` / `StateTransitionStatus` | 應用事件的結果與狀態枚舉 |
| `StateMachineContext` | 運行時執行上下文,可供領域模塊擴展 |

## 設計說明

- 完全泛型(無媒體特定類型);機器 vs 控制器 = 執行 vs 編排。無跨模塊導入。

## 依賴

- 無內部依賴
