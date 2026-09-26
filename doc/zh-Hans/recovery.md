# recovery 模块

> 播放恢复：失败后决定并调度恢复动作（重试/重启/重新初始化/停止）。

## 模块职责

- 以 sealed `RecoveryAction` 表示决策值（非执行请求）。
- `RecoveryManager` 启动恢复、跟踪上下文与尝试次数、调度重试、完成或耗尽。
- `RetryScheduler` 只管重试时序的计算与执行。

## 核心 API

| API | 说明 |
| --- | --- |
| `RecoveryAction` | sealed 决策：`None/Retry/Restart/Reinitialize/Stop`（仅是值，不是执行请求） |
| `RecoveryReason` | sealed 原因：Unknown/Network/Timeout/Decoder/Renderer/Source/Initialization/Interrupted/Resource |
| `RecoveryManager` | 启动恢复、跟踪 context/attempts、调度重试、complete/exhaust；暴露 `RecoverySnapshot` |
| `RetryScheduler` / `RetryState` | 只管重试时序 / 重试序号与尝试计数 |
| `RecoveryState` | 生命周期：idle → … → complete/exhaust（见类文档流程） |
| `RecoveryContext` / `RecoverySnapshot` | 不可变身份/诊断数据与只读状态视图 |

## 设计说明

- 策略（action）与执行（manager）与诊断（reason/snapshot）严格分离。

## 依赖

- 内部：`identity`（SourceId、RequestId、OperationId、GenerationId）
