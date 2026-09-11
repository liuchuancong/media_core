# bug 模塊

> 除錯與故障注入基礎設施:Bug 模式、故障配置、Hook、注入器、調度器與場景,用於測試播放器的韌性。

## 模塊職責

- 提供 `BugMode` 強度等級(disabled/safe/normal/aggressive/chaos)控制故障注入的許可權。
- 以宣告式 `FaultConfig` 描述單次注入(類型、機率、延遲、時長、次數上限)。
- 通過 `BugHook` 注入點在模塊內部執行故障行為,並記錄 `FaultEvent`。
- 支持可重複的故障場景(`FaultScenario`)。

## 核心 API

| API | 說明 |
| --- | --- |
| `BugMode` / `BugModeConfig` / `BugModeController` | 故障模式值對象 + 不可變配置 + 可變運行時控制器(廣播配置流、許可判定) |
| `BugHook` / `BugHooks` | 模塊級掛鉤接口與註冊表:判定是否支持某 `FaultConfig` 並執行故障 |
| `FaultType` | 可擴展的語義故障類型值對象 |
| `FaultConfig` | 一次注入的描述;提供 `deterministic` / `random` 機率構造 |
| `FaultInjector` | 協調許可檢查、活動故障登記、故障 ID 生成、Hook 選擇與事件創建 |
| `FaultScheduler` | 只管時序:`schedule` / `scheduleDelayed` / `scheduleScenario` |
| `FaultScenario` / `FaultEvent` | 命名可重複的故障集合 / 已注入故障的記錄 |

## 設計說明

- 分層管線:FaultScenario/FaultScheduler → FaultInjector → BugHook;每層文檔明確標註「不做的事」(許可 vs 時序 vs 執行)。

## 依賴

- 外部:`equatable`、`package:clock`(測試友好時間)
