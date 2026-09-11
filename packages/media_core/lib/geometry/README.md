# geometry 模塊

> 視頻幾何:視頻/顯示尺寸、寬高比、旋轉、方向與像素密度等不可變值對象,以及帶過期防護的幾何狀態控制器。

## 模塊職責

- 純描述層:建模視頻幾何信息,不做佈局、不調整 widget、不調用平台 API。
- `GeometryController` 以響應式流維護幾何狀態,並用 generation 計數丟棄過期的異步更新。

## 核心 API

| API | 說明 |
| --- | --- |
| `VideoSize` | int 源尺寸;`fitWidth/fitHeight/transpose/scale` |
| `DisplaySize` | double 輸出尺寸;`fitInside/cover/scale` |
| `AspectRatioValue` | 歸一化寬高比(默認回退 16:9);clamp、invert、widthForHeight |
| `PixelRatioValue` | 邏輯↔物理像素換算 |
| `VideoRotationInfo` | 0/90/180/270 歸一化旋轉;`swapsAspectRatio`、`quarterTurns`、`inverse` |
| `VideoOrientation` / `VideoOrientationInfo` | 方向枚舉 + 旋轉感知的 `effectiveOrientation` 與 mirrored 標誌 |
| `VideoGeometry` | 六者聚合;旋轉後的 `effectiveWidth/Height/AspectRatio`;`canRender` |
| `GeometryController` | 持有 `BehaviorSubject<GeometryState>`;`update/updateVideoSize/updateDisplaySize/updateRotation/clear`、`dispatch(event)`、`restore`,帶 generation 計數 |
| `GeometryState` / `GeometryEvent` / `GeometrySnapshot` / `GeometrySession` | 不可變狀態(含 `reduce`)、sealed 事件、只讀快照、幾何生命週期會話(`accepts` generation 校驗) |

## 設計說明

- 自包含模塊,無內部跨模塊依賴;所有值對象支持 `toMap`/`fromMap`。

## 依賴

- 外部:`rxdart`、`clock`、`equatable`
