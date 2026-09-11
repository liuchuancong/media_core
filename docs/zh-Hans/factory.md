# factory 模块

> 播放器/后端工厂：后端注册表、基于能力的后端选择，以及 media_core 对外的播放器创建入口。

## 模块职责

- 注册并查找播放后端（media_kit、vlc、exoplayer 等）的描述符与工厂。
- 按能力与偏好打分选出最合适的后端。
- 提供公开的 `PlayerFactory` 作为播放器创建入口。

## 核心 API

| API | 说明 |
| --- | --- |
| `BackendCapabilities` | 后端能力集（live、vod、seek、pause、speed、audioOnly、网络/本地、硬/软解、字幕、音轨、旋转、截图、平台）；附派生判定 getter |
| `BackendDescriptor` | 后端元数据：id、name、version、`factory`、能力、选择优先级、启用状态 |
| `BackendFactory` / `BackendInstance` | 创建后端实例（`create/warmUp/dispose`）与单个后端运行时（`initialize/dispose`）接口 |
| `BackendRegistry` | 注册/注销/查找/启用判定/`findByPlatform`；只做存储与查找 |
| `BackendSelector` | `select(BackendSelectionRequest)`：禁用/平台不支持/缺必需能力直接淘汰（−1），再按偏好（首选后端 +1000、硬解 +100、低延迟 +50、网络/本地匹配 +30、可解码 +10）与描述符优先级打分 |
| `BackendSelectionRequest` / `BackendSelectionResult` / `BackendSelectionReject` | 选择的输入/输出（含分数与淘汰原因） |
| `PlayerFactory` | `create({PlayerFactoryConfig?})` → `Player`；media_core 的公开创建入口 |
| `PlayerFactoryConfig` | 创建期选项：preferredBackend、platform、autoInitialize、enableDiagnostics、enableHardwareDecode、enableFallback、可选 `PlayerPolicy` |

## 设计说明

- Selector / Registry / Factory / Instance 职责在文档中严格切分；Selector 不注册，Registry 不选择。

## 依赖

- 内部：`source`（SourceDescriptor / SourceLocation）、`policy`（PlayerPolicy）、`core`（Player）
