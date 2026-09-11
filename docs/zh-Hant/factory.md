# factory 模塊

> 播放器/後端工廠:後端註冊表、基於能力的後端選擇,以及 media_core 對外的播放器創建入口。

## 模塊職責

- 註冊並查找播放後端(media_kit、vlc、exoplayer 等)的描述符與工廠。
- 按能力與偏好打分選出最合適的後端。
- 提供公開的 `PlayerFactory` 作為播放器創建入口。

## 核心 API

| API | 說明 |
| --- | --- |
| `BackendCapabilities` | 後端能力集(live、vod、seek、pause、speed、audioOnly、網絡/本地、硬/軟解、字幕、音軌、旋轉、截圖、平台);附派生判定 getter |
| `BackendDescriptor` | 後端元數據:id、name、version、`factory`、能力、選擇優先級、啟用狀態 |
| `BackendFactory` / `BackendInstance` | 創建後端實例(`create/warmUp/dispose`)與單個後端運行時(`initialize/dispose`)接口 |
| `BackendRegistry` | 註冊/註銷/查找/啟用判定/`findByPlatform`;只做存儲與查找 |
| `BackendSelector` | `select(BackendSelectionRequest)`:禁用/平台不支持/缺必需能力直接淘汰(−1),再按偏好(首選後端 +1000、硬解 +100、低延遲 +50、網絡/本地匹配 +30、可解碼 +10)與描述符優先級打分 |
| `BackendSelectionRequest` / `BackendSelectionResult` / `BackendSelectionReject` | 選擇的輸入/輸出(含分數與淘汰原因) |
| `PlayerFactory` | `create({PlayerFactoryConfig?})` → `Player`;media_core 的公開創建入口 |
| `PlayerFactoryConfig` | 創建期選項:preferredBackend、platform、autoInitialize、enableDiagnostics、enableHardwareDecode、enableFallback、可選 `PlayerPolicy` |

## 設計說明

- Selector / Registry / Factory / Instance 職責在文檔中嚴格切分;Selector 不註冊,Registry 不選擇。

## 依賴

- 內部:`source`(SourceDescriptor / SourceLocation)、`policy`(PlayerPolicy)、`core`(Player)
