# audio 模块

> 平台无关的音频子系统管理：音频焦点（Audio Focus）、音频会话（Session）、输出路由、音量与静音。

## 模块职责

- 管理音频子系统的高层生命周期：激活/去激活（先会话后焦点，失败自动回滚）。
- 以响应式流暴露 `enabled` / `active` / `focused` 状态。
- 将 Android 焦点、iOS AVAudioSession 打断等平台细节隐藏在接口之后。

## 核心 API

| API | 说明 |
| --- | --- |
| `AudioManager` | 高层门面：`activate/deactivate`、`abandonFocus/requestFocus`、`setEnabled`，幂等 `dispose` |
| `AudioCoordinator` | 协调层：把焦点+会话整合为 `AudioFocusState` / `AudioSessionState` 流；以单调 `generation` 计数拒绝过期的异步平台回调 |
| `AudioFocus` / `AudioSession` | 平台抽象接口（实现由平台适配层提供） |
| `AudioRoute` / `AudioRouteKind` | 输出路由的粗粒度描述（扬声器等） |
| `AudioVolume` / `AudioMute` | 归一化音量（0.0–1.0）与静音值对象 |
| `AudioFocusState` / `AudioSessionState` | 不可变状态快照 |

## 设计说明

- 所有生命周期操作通过链式 future 队列串行化，防止竞态。
- 职责分层清晰：Focus/Session 是平台接缝，Coordinator 整合状态，Manager 对外。

## 依赖

- 外部：`rxdart`（BehaviorSubject / ValueStream）、`equatable`
