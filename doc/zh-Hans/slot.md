# slot 模块

> 逻辑播放器槽位：槽位的所有权、分配与状态——把会话/播放器映射到一组有界的播放器槽位上。

## 模块职责

- 定义逻辑槽位实体、分配记录与所有权语义。
- 与物理播放器创建（`factory`/`session`）及实例池（`pool`）分离。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerSlot` | 逻辑槽位实体 |
| `PlayerSlotManager` | 槽位生命周期/分配管理；不创建播放器 |
| `PlayerSlotAssignment` | 槽位↔会话↔播放器的分配记录 |
| `PlayerSlotOwner` / `PlayerSlotOwnerType` | 所有权语义与类别 |
| `PlayerSlotState` / `PlayerSlotStatus` / `PlayerSlotSnapshot` | 状态 / 状态枚举 / 只读快照 |

## 设计说明

- 槽位层级：SlotId → PlayerId → SessionId（见 `identity` 文档）。

## 依赖

- 内部：`identity`（SlotId、SessionId、PlayerId）
