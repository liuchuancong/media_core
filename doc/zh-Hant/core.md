# core 模塊

> 播放器領域模型的公共核心:身份、狀態、配置、選項、能力、信息、指標、錯誤與快照等基礎不可變值對象。

## 模塊職責

- 定義 `Player` 身份、語義化 `PlayerState`、完整可觀測狀態 `PlayerSnapshot`。
- 區分創建期配置(`PlayerConfig`)與運行期選項(`PlayerOptions`)。
- 描述實現能力(`PlayerCapabilities`)與當前媒體能力(`MediaCapabilities`)。

## 核心 API

| API | 說明 |
| --- | --- |
| `Player` | 穩定播放器身份(僅按 `PlayerId` 判等);`Player.create()` 生成 id |
| `PlayerState` | 語義運行狀態(freezed):`PlayerLifecycleState`(idle/initializing/ready/disposing/disposed)+ `PlayerPlaybackState`(playing/paused/buffering/seeking/…)+ hasSource/audio/video/muted 標誌 |
| `PlayerSnapshot` | 完整不可變可觀測狀態:各 id、媒體類型/能力、狀態、選項、能力、指標、時間戳 |
| `PlayerConfig` / `PlayerOptions` | 不可變創建配置 vs 運行選項(autoPlay、loop、volume、解碼偏好、恢復/降級開關與次數上限) |
| `PlayerCapabilities` | 實現能力:play/seek/PiP/fullscreen/frameStep… |
| `MediaCapabilities` / `MediaType` | 當前媒體的能力(音/視/字幕軌、可 seek、直播)與類型 |
| `PlayerInfo` | 穩定描述性元數據(title、author、bitrate、尺寸…,freezed) |
| `PlayerMetrics` | 後端無關的播放/緩衝/渲染/網絡測量,供診斷 |
| `PlayerError` | 不可變錯誤快照:code、分類器解析出的 category、cause、上下文 id |
| `PlayerStatus` + `PlayerStatusX` | 由狀態派生的高層狀態枚舉與便捷判定 |
| `PlayerConstants` | 共享默認值/上限(音量/速率邊界、超時、seek 容差) |

## 設計說明

- 嚴格區分 config / state / options / capabilities / media capabilities 五個層次,每個類的文檔都有明確邊界說明。
- `PlayerState`、`PlayerInfo` 使用 freezed 並支持 JSON 序列化。

## 依賴

- 內部:`identity`(各類 id)、`error`(ErrorClassifier、code、category)
- 外部:`freezed`、`equatable`、`clock`
