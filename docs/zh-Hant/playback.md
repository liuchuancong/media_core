# playback 模塊

> 播放控制:播放命令、狀態、進度、時長與選項;擁有與後端無關的播放狀態機。

## 模塊職責

- 以 sealed 命令集(`PlaybackCommand`)表達播放狀態變更。
- `PlaybackController` 通過 BehaviorSubject 持有並對外暴露播放狀態,操作經內部 future 隊列串行化。
- 不解碼媒體、不控制後端、不調用平台 API。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlaybackCommand` | sealed 命令:`.idle()/.play()/.pause()/.stop()/.buffering()/.position()/.duration()/.seek()/.volume()/.rate()`,附狀態判定 |
| `PlaybackController` | 狀態持有者:`state`(ValueStream)、`current`、`snapshot`、`request(PlaybackRequest)` |
| `PlaybackState` | 運行狀態:command、position、duration、volume、rate、initialized、updatedAt(經 `clock`) |
| `PlaybackSnapshot` | 不可變只讀視圖,供 Player API / UI / 診斷使用 |
| `PlaybackRequest` / `PlaybackOptions` | 外部操作包裝 / 起播前配置 |
| `PlaybackPosition` / `PlaybackDuration` / `PlaybackRate` / `PlaybackVolume` / `PlaybackCommandType` | 值對象與命令枚舉 |

## 設計說明

- 命令模式 + sealed 聯合類型;自包含模塊,無內部跨模塊依賴。

## 依賴

- 外部:`rxdart`、`equatable`、`clock`
