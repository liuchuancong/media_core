# state_machine 模块

> 通用的、领域无关的状态机基础设施：状态、事件、转换与编排。

## 模块职责

- 提供泛型状态机（状态 + 事件 + 转换定义 + 守卫）。
- 机器只管转换执行；控制器围绕机器做运行时编排（生命周期、队列）。

## 核心 API

| API | 说明 |
| --- | --- |
| `StateMachine<S>` | 只拥有转换执行；无持久化/生命周期/重试 |
| `StateMachineController<S>` | 运行时编排：生命周期与队列；不替换机器、不实现重试策略 |
| `StateMachineState` | 不可变状态契约；无副作用 |
| `StateMachineEvent` | 事件值对象 |
| `StateTransition<S>` / `StateTransitionGuard<S>` | 转换定义 / 守卫 typedef |
| `StateTransitionResult<S>` / `StateTransitionStatus` | 应用事件的结果与状态枚举 |
| `StateMachineContext` | 运行时执行上下文，可供领域模块扩展 |

## 设计说明

- 完全泛型（无媒体特定类型）；机器 vs 控制器 = 执行 vs 编排。无跨模块导入。

## 依赖

- 无内部依赖
