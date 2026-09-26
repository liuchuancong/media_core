# recording 模块

> 录制抽象：录制会话、格式与后端，用于捕获媒体（来自播放器、设备输入等）。

## 模块职责

- 管理多个录制会话与其生命周期编排。
- 把平台相关的写入/编码委托给 `RecordingBackend` 实现。
- 描述录制来源、配置、容器/编解码器偏好与结果。

## 核心 API

| API | 说明 |
| --- | --- |
| `RecordingManager` | 管理多个录制会话，编排生命周期 |
| `RecordingSession` | 一次录制的生命周期；不自行写媒体数据或选择平台 API |
| `RecordingBackend` | 平台合约：`start(source, config)`、`stop()`、`cancel()`、`dispose()`；实现负责写/编码文件 |
| `RecordingSource` / `RecordingSourceType` | 录制媒体的语义来源（与 player/network 层解耦） |
| `RecordingConfig` | 用户配置；不选后端、不启停 |
| `RecordingFormat` / `RecordingContainer` / `RecordingVideoCodec` / `RecordingAudioCodec` | 后端无关的容器与编解码器偏好 |
| `RecordingState` / `RecordingStatus` / `RecordingResult` | 会话生命周期状态 / 完成结果 |

## 设计说明

- 强分层纪律：每个类的文档都列出「不做的事」；无跨模块导入，完全解耦。

## 依赖

- 无内部依赖
