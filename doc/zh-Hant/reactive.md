# reactive 模塊

> 響應式抽象與流工具:基於 rxdart 的共享工具箱,供控制器、倉庫、服務與播放器管理器使用;不依賴 Flutter。

## 模塊職責

- 統一的主體(subject)抽象與靜態工廠。
- 提供並發/時序控制(互斥、閘門、隊列、調度器)。
- 提供狀態/結果包裝、流操作符與生命週期輔助。

## 核心 API(節選)

| API | 說明 |
| --- | --- |
| `Reactive` | 靜態工廠門面(廣播/單訂閱控制器);底層仍是 rxdart |
| `ReactiveSubject<T>` / `ReactiveBehavior<T>` | 同為 Stream+Sink 的主體接口 / BehaviorSubject 背書、總能給出最新值 |
| `StreamMutex` / `StreamGate` / `StreamQueue` | 異步互斥(串行 `run()`)/ 忽略過期異步操作的閘門 / 串行任務隊列 |
| `StreamScheduler` | 可 dispose 安全的延遲/週期調度器 |
| `StreamState` / `StreamResult` / `StreamSafe` / `StreamSafeResult` | 狀態持有 / 異步操作狀態與結果 / 錯誤轉結果的包裝輔助 |
| `debounce` / `throttle` / `combine` / `distinct` / `stream_transform` / `stream_extensions` | 流操作符與擴展 |
| `stream_disposable` / `stream_cancellation` / `stream_lifecycle` / `stream_cache` / `stream_retry` / `stream_debouncer` 等 | 可釋放資源管理、取消、生命週期、帶 TTL 內存緩存、重試配置等輔助 |

## 設計說明

- 定位是包裝 rxdart 而非取代它;所有工具都是 dispose 感知的。
- 葉子模塊,無內部跨模塊依賴。

## 依賴

- 外部:`rxdart`、`dart:async`
