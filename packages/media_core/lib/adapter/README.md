# adapter 模塊

> 後端無關的播放器適配器抽象:定義統一的播放引擎合約(PlayerAdapter)、工廠、註冊表與能力選擇。

## 模塊職責

- 定義 `PlayerAdapter` 統一合約,讓 media_kit、native、video_player 等具體播放引擎以相同方式接入。
- 提供適配器的創建(Factory)、註冊與查找(Registry)、以及基於能力的候選選擇(Selector)。
- 定義適配器層的事件、狀態、指標與能力描述等值對象。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerAdapter` | 播放後端的抽象合約:`open/play/pause/stop/seek/setVolume/setRate/close/dispose`,暴露 `state`、`events`、`metrics`、`capabilities` |
| `PlayerAdapterFactory` / `DefaultPlayerAdapterFactory` | 按標識創建適配器實例;註冊匿名創建函數,隱藏具體實現 |
| `PlayerAdapterRegistry` / `PlayerAdapterRegistration` | 存儲適配器元數據(id、工廠、能力、優先級、啟用狀態),只負責查找 |
| `PlayerAdapterSelector` | 依據能力(live/seek/協議/格式)與優先級為 `SourceDescriptor` 選出最佳適配器,並提供候補列表 |
| `PlayerAdapterCapabilities` | 靜態能力描述:直播、seek、PiP、硬解、支持的協議與格式 |
| `PlayerAdapterEvent` | 後端事件閉集(freezed):opened/playing/paused/buffering/completed/position/duration/videoSize/volume/rate/error |
| `PlayerAdapterState` / `PlayerAdapterConfig` / `PlayerAdapterContext` / `PlayerAdapterError` / `PlayerAdapterMetrics` | 周邊不可變值對象 |

## 設計說明

- 嚴格單一職責:Adapter 執行、Factory 創建、Registry 存儲、Selector 決策。
- 降級(fallback)處理委託給 `fallback` 模塊的 `FallbackManager`,本模塊只產生候選順序。
- 事件提供 `isError` / `affectsPlayback` / `affectsGeometry` 等判定擴展。

## 依賴

- 內部:`core`(PlayerState)、`source`(PlayerSource / SourceDescriptor)
- 外部:`freezed`、`equatable`
