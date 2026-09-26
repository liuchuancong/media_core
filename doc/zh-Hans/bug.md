# bug 模块

> 调试与故障注入基础设施：Bug 模式、故障配置、Hook、注入器、调度器与场景，用于测试播放器的韧性。

## 模块职责

- 提供 `BugMode` 强度等级（disabled/safe/normal/aggressive/chaos）控制故障注入的权限。
- 以声明式 `FaultConfig` 描述单次注入（类型、概率、延迟、时长、次数上限）。
- 通过 `BugHook` 注入点在模块内部执行故障行为，并记录 `FaultEvent`。
- 支持可重复的故障场景（`FaultScenario`）。

## 核心 API

| API | 说明 |
| --- | --- |
| `BugMode` / `BugModeConfig` / `BugModeController` | 故障模式值对象 + 不可变配置 + 可变运行时控制器（广播配置流、许可判定） |
| `BugHook` / `BugHooks` | 模块级挂钩接口与注册表：判定是否支持某 `FaultConfig` 并执行故障 |
| `FaultType` | 可扩展的语义故障类型值对象 |
| `FaultConfig` | 一次注入的描述；提供 `deterministic` / `random` 概率构造 |
| `FaultInjector` | 协调许可检查、活动故障登记、故障 ID 生成、Hook 选择与事件创建 |
| `FaultScheduler` | 只管时序：`schedule` / `scheduleDelayed` / `scheduleScenario` |
| `FaultScenario` / `FaultEvent` | 命名可重复的故障集合 / 已注入故障的记录 |

## 设计说明

- 分层管线：FaultScenario/FaultScheduler → FaultInjector → BugHook；每层文档明确标注「不做的事」（许可 vs 时序 vs 执行）。

## 依赖

- 外部：`equatable`、`package:clock`（测试友好时间）
