# core 模块

> 播放器领域模型的公共核心：身份、状态、配置、选项、能力、信息、指标、错误与快照等基础不可变值对象。

## 模块职责

- 定义 `Player` 身份、语义化 `PlayerState`、完整可观测状态 `PlayerSnapshot`。
- 区分创建期配置（`PlayerConfig`）与运行期选项（`PlayerOptions`）。
- 描述实现能力（`PlayerCapabilities`）与当前媒体能力（`MediaCapabilities`）。

## 核心 API

| API | 说明 |
| --- | --- |
| `Player` | 稳定播放器身份（仅按 `PlayerId` 判等）；`Player.create()` 生成 id |
| `PlayerState` | 语义运行状态（freezed）：`PlayerLifecycleState`（idle/initializing/ready/disposing/disposed）+ `PlayerPlaybackState`（playing/paused/buffering/seeking/…）+ hasSource/audio/video/muted 标志 |
| `PlayerSnapshot` | 完整不可变可观测状态：各 id、媒体类型/能力、状态、选项、能力、指标、时间戳 |
| `PlayerConfig` / `PlayerOptions` | 不可变创建配置 vs 运行选项（autoPlay、loop、volume、解码偏好、恢复/降级开关与次数上限） |
| `PlayerCapabilities` | 实现能力：play/seek/PiP/fullscreen/frameStep… |
| `MediaCapabilities` / `MediaType` | 当前媒体的能力（音/视/字幕轨、可 seek、直播）与类型 |
| `PlayerInfo` | 稳定描述性元数据（title、author、bitrate、尺寸…，freezed） |
| `PlayerMetrics` | 后端无关的播放/缓冲/渲染/网络测量，供诊断 |
| `PlayerError` | 不可变错误快照：code、分类器解析出的 category、cause、上下文 id |
| `PlayerStatus` + `PlayerStatusX` | 由状态派生的高层状态枚举与便捷判定 |
| `PlayerConstants` | 共享默认值/上限（音量/速率边界、超时、seek 容差） |

## 设计说明

- 严格区分 config / state / options / capabilities / media capabilities 五个层次，每个类的文档都有明确边界说明。
- `PlayerState`、`PlayerInfo` 使用 freezed 并支持 JSON 序列化。

## 依赖

- 内部：`identity`（各类 id）、`error`（ErrorClassifier、code、category）
- 外部：`freezed`、`equatable`、`clock`
