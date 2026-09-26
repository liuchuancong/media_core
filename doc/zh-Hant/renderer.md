# renderer 模塊

> Flutter widget 層渲染抽象:播放器的 surface、視圖與覆蓋層,以及渲染器狀態。

## 模塊職責

- 提供播放器顯示的組合 widget(view、surface、renderer、overlay)。
- `RendererController` 編排渲染狀態轉換;不創建平台 surface、不控制播放。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerView` | 頂層組合 widget;把實際 surface 委託給 `PlayerSurface` |
| `PlayerSurface` | 平台渲染 surface 槽位(texture/platform view 的創建在別處) |
| `PlayerRenderer` | 組裝各視圖部件;不做播放控制、不做幾何計算 |
| `PlayerOverlay` | 調用方提供的 UI 覆蓋層(控制條、加載、手勢、彈幕、調試信息) |
| `RendererController` | 編排渲染狀態轉換 |
| `RendererState` / `RendererConfig` / `RendererCapabilities` | 不可變渲染狀態 / 配置與能力描述(僅信息性) |

## 設計說明

- 純呈現層;每個 widget 都明確聲明不做播放控制、平台資源創建與幾何計算。無跨模塊導入。

## 依賴

- 外部:Flutter widget 框架
