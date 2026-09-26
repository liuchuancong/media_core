# coordinator 模块

> 跨模块协调层：按 `PlayerId` 将播放器绑定到各子系统控制器/管理器，并在它们之间转发请求；自身不执行任何操作。

## 模块职责

- 作为组合根（`GlobalPlayerCoordinator`）聚合播放、页面、音频、资源、预载、生命周期与呈现协调器。
- 统一采用「注册/注销/查找 + `request(...)` 转发」的模式，把请求路由到对应子系统。
- 不创建播放器、不调用平台 API、不保存播放状态。

## 核心 API

| API | 说明 |
| --- | --- |
| `GlobalPlayerCoordinator` | 根组合：聚合下列各协调器（均可惰性给默认值） |
| `PlaybackCoordinator` | 每播放器绑定 `PlaybackController`，转发 `PlaybackRequest` |
| `PlayerCoordinator` | 绑定 `Player`/`PlayerSession` 对，承担高层播放器工作流 |
| `PlayerAudioCoordinator` | 注册每播放器的 `AudioManager`；每播放器音量/静音与响应式流；操作串行化、销毁幂等 |
| `LifecycleCoordinator` | 每播放器绑定 `PlayerLifecycle` 处理器，分发生命周期事件 |
| `PageCoordinator` | 页面↔播放器绑定（`attachPlayer/detachPlayer`、活跃页面） |
| `PreloadCoordinator` | 每播放器绑定 `PreloadManager`，转发预载请求 |
| `ResourceCoordinator` | 每播放器绑定 `ResourceManager`，应用资源压力决策 |
| `PresentationCoordinator` | 每播放器绑定 `PresentationController`，路由呈现请求 |

## 设计说明

- 协调器永远只是「绑定 + 转发」；实际职责分属 PlayerFactory / PlayerAdapter / PlaybackController 等。
- 适合在应用层通过 `GlobalPlayerCoordinator` 统一拿各子系统入口。

## 依赖

- 内部：`identity`、`core`、`session`、`playback`、`audio`、`lifecycle`、`preload`、`presentation`、`resource`
- 外部：`rxdart`
