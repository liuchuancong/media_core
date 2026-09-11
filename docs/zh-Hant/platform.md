# platform 模塊

> 平台能力與平台特定抽象:純描述性值類型,描述當前運行環境支持什麼;不做任何原生 API 訪問。

## 模塊職責

- 描述運行平台類型與環境信息。
- 描述編解碼、渲染、音頻、字幕、PiP、全屏、後台、網絡等能力旗標。
- 定義 `PlatformProvider` 接口作為 media core 與宿主平台之間的抽象層。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlatformType` | 平台類型值對象:android/ios/windows/macos/linux/web/tv,附解析 |
| `PlatformProvider` | 抽象接口:`type`、`info`、`capabilities`、`isReady`;檢測與原生查詢由其實現承擔 |
| `PlatformInfo` | 不可變運行環境信息 |
| `PlatformCapabilities` | 編解碼/渲染/音頻/字幕/PiP/全屏/後台/網絡能力旗標 |
| `PlatformLifecycle` | 後台播放、非活躍暫停、回前台恢復、掛起等旗標 |
| `PlatformPip` | 系統 PiP vs 自定義懸浮窗、自動進入、可調整大小 |
| `PlatformSurface` | 視頻輸出 surface 描述(類型、縮放/旋轉支持、texture id) |
| `PlatformAudio` / `PlatformNetwork` / `PlatformRenderer` | 音頻/網絡/渲染能力描述符 |

## 設計說明

- 完全的葉子模塊,零內部跨模塊依賴;原生檢測委託給 `PlatformProvider` 實現與 `factory` 模塊的 `BackendFactory`。

## 依賴

- 外部:`equatable`
