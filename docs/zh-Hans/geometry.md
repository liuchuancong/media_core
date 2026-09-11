# geometry 模块

> 视频几何：视频/显示尺寸、宽高比、旋转、方向与像素密度等不可变值对象，以及带过期防护的几何状态控制器。

## 模块职责

- 纯描述层：建模视频几何信息，不做布局、不调整 widget、不调用平台 API。
- `GeometryController` 以响应式流维护几何状态，并用 generation 计数丢弃过期的异步更新。

## 核心 API

| API | 说明 |
| --- | --- |
| `VideoSize` | int 源尺寸；`fitWidth/fitHeight/transpose/scale` |
| `DisplaySize` | double 输出尺寸；`fitInside/cover/scale` |
| `AspectRatioValue` | 归一化宽高比（默认回退 16:9）；clamp、invert、widthForHeight |
| `PixelRatioValue` | 逻辑↔物理像素换算 |
| `VideoRotationInfo` | 0/90/180/270 归一化旋转；`swapsAspectRatio`、`quarterTurns`、`inverse` |
| `VideoOrientation` / `VideoOrientationInfo` | 方向枚举 + 旋转感知的 `effectiveOrientation` 与 mirrored 标志 |
| `VideoGeometry` | 六者聚合；旋转后的 `effectiveWidth/Height/AspectRatio`；`canRender` |
| `GeometryController` | 持有 `BehaviorSubject<GeometryState>`；`update/updateVideoSize/updateDisplaySize/updateRotation/clear`、`dispatch(event)`、`restore`，带 generation 计数 |
| `GeometryState` / `GeometryEvent` / `GeometrySnapshot` / `GeometrySession` | 不可变状态（含 `reduce`）、sealed 事件、只读快照、几何生命周期会话（`accepts` generation 校验） |

## 设计说明

- 自包含模块，无内部跨模块依赖；所有值对象支持 `toMap`/`fromMap`。

## 依赖

- 外部：`rxdart`、`clock`、`equatable`
