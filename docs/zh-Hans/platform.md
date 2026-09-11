# platform 模块

> 平台能力与平台特定抽象：纯描述性值类型，描述当前运行环境支持什么；不做任何原生 API 访问。

## 模块职责

- 描述运行平台类型与环境信息。
- 描述编解码、渲染、音频、字幕、PiP、全屏、后台、网络等能力旗标。
- 定义 `PlatformProvider` 接口作为 media core 与宿主平台之间的抽象层。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlatformType` | 平台类型值对象：android/ios/windows/macos/linux/web/tv，附解析 |
| `PlatformProvider` | 抽象接口：`type`、`info`、`capabilities`、`isReady`；检测与原生查询由其实现承担 |
| `PlatformInfo` | 不可变运行环境信息 |
| `PlatformCapabilities` | 编解码/渲染/音频/字幕/PiP/全屏/后台/网络能力旗标 |
| `PlatformLifecycle` | 后台播放、非活跃暂停、回前台恢复、挂起等旗标 |
| `PlatformPip` | 系统 PiP vs 自定义悬浮窗、自动进入、可调整大小 |
| `PlatformSurface` | 视频输出 surface 描述（类型、缩放/旋转支持、texture id） |
| `PlatformAudio` / `PlatformNetwork` / `PlatformRenderer` | 音频/网络/渲染能力描述符 |

## 设计说明

- 完全的叶子模块，零内部跨模块依赖；原生检测委托给 `PlatformProvider` 实现与 `factory` 模块的 `BackendFactory`。

## 依赖

- 外部：`equatable`
