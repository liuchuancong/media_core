# recording 模塊

> 錄製抽象:錄製會話、格式與後端,用於捕獲媒體(來自播放器、設備輸入等)。

## 模塊職責

- 管理多個錄製會話與其生命週期編排。
- 把平台相關的寫入/編碼委託給 `RecordingBackend` 實現。
- 描述錄製來源、配置、容器/編解碼器偏好與結果。

## 核心 API

| API | 說明 |
| --- | --- |
| `RecordingManager` | 管理多個錄製會話,編排生命週期 |
| `RecordingSession` | 一次錄製的生命週期;不自行寫媒體數據或選擇平台 API |
| `RecordingBackend` | 平台合約:`start(source, config)`、`stop()`、`cancel()`、`dispose()`;實現負責寫/編碼文件 |
| `RecordingSource` / `RecordingSourceType` | 錄製媒體的語義來源(與 player/network 層解耦) |
| `RecordingConfig` | 用戶配置;不選後端、不啟停 |
| `RecordingFormat` / `RecordingContainer` / `RecordingVideoCodec` / `RecordingAudioCodec` | 後端無關的容器與編解碼器偏好 |
| `RecordingState` / `RecordingStatus` / `RecordingResult` | 會話生命週期狀態 / 完成結果 |

## 設計說明

- 強分層紀律:每個類的文檔都列出「不做的事」;無跨模塊導入,完全解耦。

## 依賴

- 無內部依賴
