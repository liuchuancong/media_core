# identity 模块

> 跨模块共享的强类型不可变标识值对象，让各实体无需依赖字符串字段即可关联。

## 模块职责

- 定义七种平行 id 类型，形状完全一致，全部 `final class ... extends Equatable implements Comparable`。
- `PlayerId` — 逻辑播放器实例
- `SessionId` — 一次播放会话（一个 player 可有多个）
- `SlotId` — 播放器池的资源槽（层级：SlotId → PlayerId → SessionId）
- `SourceId` — 逻辑媒体源；额外 `unknown()` 工厂与 `isUnknown`
- `OperationId` — 一个逻辑操作（open/play/seek/…）
- `RequestId` — 操作内一个具体请求（操作 : 请求 = 1 : N，对应重试/后端步骤）
- `GenerationId` — 生命周期代数，专门用于丢弃过期的异步结果（详见类文档图解）

## 通用 API（每个 id 类型一致）

- `X(value)` 工厂：trim 并在空串时抛 `ArgumentError`
- `X.generate()`：基于 `clock.now` 的时间戳+计数器（如 `player_<us>_<n>`），测试可控
- `parse` / `isValid` / `fromJson` / `toJson`（原始字符串）
- `isSameAs` / `isDifferentFrom` / `compareTo`

## 设计说明

- 基础层模块，仅依赖外部包。
- `identity_json_converters.dart` 提供各 id 的 `JsonConverter`，供 json_serializable 集成。

## 依赖

- 外部：`equatable`、`clock`、`json_annotation`
