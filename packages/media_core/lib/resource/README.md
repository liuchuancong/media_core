# resource 模塊

> 資源管理:解碼器、內存、帶寬與溫度資源的預算、分域管理器、壓力計算與中心 ResourceManager。

## 模塊職責

- 各域管理器產生使用快照,結合預算計算資源壓力。
- `ResourceManager` 聚合各域壓力並產出 `ResourceSnapshot`(壓力可能觸發降清晰度、停預載、切流等上層決策)。

## 核心 API

| API | 說明 |
| --- | --- |
| `ResourceManager` | 中心聚合器:消費各域壓力,產出 `ResourceSnapshot` |
| `DecoderManager` / `MemoryManager` / `BandwidthManager` / `ThermalManager` | 四個分域管理器,各自帶使用快照(`XUsageSnapshot` / `ThermalSnapshot`) |
| `DecoderBudget` / `MemoryBudget` / `BandwidthBudget` | 分配上限與校驗 |
| `ResourcePressure` / `ResourcePressureSnapshot` | 壓力枚舉與壓力快照,餵給 ResourceManager |
| `ThermalState` / `ResourcePriority` / `ResourceState` / `ResourceMetrics` / `ResourceSnapshot` | 溫度狀態 / 優先級 / 狀態 / 指標 / 只讀總覽快照(供 UI/調試/指標) |

## 設計說明

- 流向(源碼有 ASCII 圖):manager → budget → pressure → ResourceManager → snapshot;快照是只讀視圖,不執行操作。

## 依賴

- 內部:`policy`(resource_policy.dart)
