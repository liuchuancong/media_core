# geometry Module

> Video geometry: immutable value objects for video/display size, aspect ratio, rotation, orientation, and pixel density, plus a geometry state controller with stale-protection.

## Module Responsibilities

- Pure description layer: models video geometry information; does not do layout, adjust widgets, or call platform APIs.
- `GeometryController` maintains geometry state via reactive streams and discards stale async updates using a generation counter.

## Core API

| API | Description |
| --- | --- |
| `VideoSize` | int source size; `fitWidth/fitHeight/transpose/scale` |
| `DisplaySize` | double output size; `fitInside/cover/scale` |
| `AspectRatioValue` | Normalized aspect ratio (defaults to 16:9); clamp, invert, widthForHeight |
| `PixelRatioValue` | Logical↔physical pixel conversion |
| `VideoRotationInfo` | Normalized rotation of 0/90/180/270; `swapsAspectRatio`, `quarterTurns`, `inverse` |
| `VideoOrientation` / `VideoOrientationInfo` | Orientation enum + rotation-aware `effectiveOrientation` and mirrored flag |
| `VideoGeometry` | Aggregation of the six above; rotated `effectiveWidth/Height/AspectRatio`; `canRender` |
| `GeometryController` | Holds `BehaviorSubject<GeometryState>`; `update/updateVideoSize/updateDisplaySize/updateRotation/clear`, `dispatch(event)`, `restore`, with generation counting |
| `GeometryState` / `GeometryEvent` / `GeometrySnapshot` / `GeometrySession` | Immutable state (with `reduce`), sealed events, read-only snapshot, geometry lifecycle session (`accepts` generation check) |

## Design Notes

- Self-contained module with no internal cross-module dependencies; all value objects support `toMap`/`fromMap`.

## Dependencies

- External: `rxdart`, `clock`, `equatable`
