# playback 模块

> 播放控制：播放命令、状态、进度、时长与选项；拥有与后端无关的播放状态机。

## 模块职责

- 以 sealed 命令集（`PlaybackCommand`）表达播放状态变更。
- `PlaybackController` 通过 BehaviorSubject 持有并对外暴露播放状态，操作经内部 future 队列串行化。
- 不解码媒体、不控制后端、不调用平台 API。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlaybackCommand` | sealed 命令：`.idle()/.play()/.pause()/.stop()/.buffering()/.position()/.duration()/.seek()/.volume()/.rate()`，附状态判定 |
| `PlaybackController` | 状态持有者：`state`（ValueStream）、`current`、`snapshot`、`request(PlaybackRequest)` |
| `PlaybackState` | 运行状态：command、position、duration、volume、rate、initialized、updatedAt（经 `clock`） |
| `PlaybackSnapshot` | 不可变只读视图，供 Player API / UI / 诊断使用 |
| `PlaybackRequest` / `PlaybackOptions` | 外部操作包装 / 起播前配置 |
| `PlaybackPosition` / `PlaybackDuration` / `PlaybackRate` / `PlaybackVolume` / `PlaybackCommandType` | 值对象与命令枚举 |

## 设计说明

- 命令模式 + sealed 联合类型；自包含模块，无内部跨模块依赖。

## 依赖

- 外部：`rxdart`、`equatable`、`clock`
