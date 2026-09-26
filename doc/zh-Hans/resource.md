# resource 模块

> 资源管理：解码器、内存、带宽与温度资源的预算、分域管理器、压力计算与中心 ResourceManager。

## 模块职责

- 各域管理器产生使用快照，结合预算计算资源压力。
- `ResourceManager` 聚合各域压力并产出 `ResourceSnapshot`（压力可能触发降清晰度、停预载、切流等上层决策）。

## 核心 API

| API | 说明 |
| --- | --- |
| `ResourceManager` | 中心聚合器：消费各域压力，产出 `ResourceSnapshot` |
| `DecoderManager` / `MemoryManager` / `BandwidthManager` / `ThermalManager` | 四个分域管理器，各自带使用快照（`XUsageSnapshot` / `ThermalSnapshot`） |
| `DecoderBudget` / `MemoryBudget` / `BandwidthBudget` | 分配上限与校验 |
| `ResourcePressure` / `ResourcePressureSnapshot` | 压力枚举与压力快照，喂给 ResourceManager |
| `ThermalState` / `ResourcePriority` / `ResourceState` / `ResourceMetrics` / `ResourceSnapshot` | 温度状态 / 优先级 / 状态 / 指标 / 只读总览快照（供 UI/调试/指标） |

## 设计说明

- 流向（源码有 ASCII 图）：manager → budget → pressure → ResourceManager → snapshot；快照是只读视图，不执行操作。

## 依赖

- 内部：`policy`（resource_policy.dart）
