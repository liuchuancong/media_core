# Media Core

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-compatible-02569B.svg)](https://flutter.dev)

> 一套面向 Flutter/Dart 的模块化媒体播放核心：以后端无关的方式抽象播放器、音视频会话、资源、缓存、并发、降级、恢复、呈现与可观测性。
>
> A modular media playback core for Flutter/Dart: backend-agnostic abstractions for players, audio/video sessions, resources, caching, concurrency, fallback, recovery, presentation, and observability.
>
> 一套面向 Flutter/Dart 的模組化媒體播放核心：以後端無關的方式抽象播放器、音視訊會話、資源、快取、併發、降級、恢復、呈現與可觀測性。

- 倉庫 / Repository: https://github.com/liuchuancong/media_core
- 授權 / License: MIT

> 其他語言版本 · Other languages: [简体中文](README.md) · [English](README.en.md)

---

## 繁體中文

### 簡介

Media Core 不是一個單一的播放器外掛程式，而是一組**職責清晰、邊界嚴格、可組合**的模組。它把播放器能力拆分為核心領域模型、適配器、工廠、會話、播放控制、音訊、快取、併發、網路、資源、策略、降級、恢復、呈現、渲染、事件、操作、任務、狀態機等子系統，並透過協調層把它們組合起來。

**設計目標：**

- **後端無關**：media_kit、native、video_player、ExoPlayer、VLC 等都可以透過適配器接入。
- **單一職責**：Adapter 執行、Factory 建立、Registry 儲存、Selector 決策、Coordinator 只轉發。
- **可測試**：大量使用 `clock`、不可變值物件、注入式介面與故障注入。
- **可擴充**：錯誤碼、故障型別、任務型別、操作型別等刻意使用值物件而非封閉 enum。
- **可觀測**：狀態、指標、事件、快照貫穿各模組。

### 模組文件

| 模組 | 說明 |
| --- | --- |
| [`adapter`](docs/zh-Hant/adapter.md) | 後端無關的播放器適配器抽象：統一播放引擎合約、工廠、註冊表與能力選擇 |
| [`audio`](docs/zh-Hant/audio.md) | 平台無關音訊子系統：音訊焦點、會話、輸出路由、音量與靜音 |
| [`bug`](docs/zh-Hant/bug.md) | 除錯與故障注入：Bug 模式、故障設定、Hook、注入器、排程器與場景 |
| [`cache`](docs/zh-Hant/cache.md) | 通用二級快取：記憶體 + 可插拔儲存、驅逐策略、過期、指標與狀態 |
| [`concurrency`](docs/zh-Hant/concurrency.md) | 非同步並發原語：鎖、互斥量、號誌量、並發上限與序列執行器 |
| [`coordinator`](docs/zh-Hant/coordinator.md) | 跨模組協調層：依 PlayerId 綁定並轉發請求，自身不執行操作 |
| [`core`](docs/zh-Hant/core.md) | 播放器領域模型公共核心：身分、狀態、設定、選項、能力、資訊、指標、錯誤與快照 |
| [`error`](docs/zh-Hant/error.md) | 錯誤體系：錯誤碼/分類、分類器、格式化器、重試/降級策略決策與失敗物件 |
| [`event`](docs/zh-Hant/event.md) | 播放器事件定義、匯流排與分發：只負責事件傳輸 |
| [`factory`](docs/zh-Hant/factory.md) | 播放器/後端工廠：後端註冊表、基於能力的後端選擇、播放器建立入口 |
| [`fallback`](docs/zh-Hant/fallback.md) | 降級機制：後端實作、播放線路 URL、清晰度檔位三個維度的退化/重試生命週期 |
| [`geometry`](docs/zh-Hant/geometry.md) | 影片幾何：影片/顯示尺寸、寬高比、旋轉、方向、像素密度與幾何狀態控制器 |
| [`identity`](docs/zh-Hant/identity.md) | 跨模組共享的強型別不可變識別值物件 |
| [`lifecycle`](docs/zh-Hant/lifecycle.md) | 播放器、頁面與應用程式生命週期：小型狀態機、事件、快照與觀察者 |
| [`network`](docs/zh-Hant/network.md) | 網路抽象：連通性狀態/條件/型別/品質、效能指標與請求/回應執行 |
| [`operation`](docs/zh-Hant/operation.md) | 高層非同步/業務操作：不可變生命週期記錄、註冊表、追蹤器、取消權杖與逾時策略 |
| [`platform`](docs/zh-Hant/platform.md) | 平台能力與平台特定抽象：純描述性值型別 |
| [`playback`](docs/zh-Hant/playback.md) | 播放控制：播放指令、狀態、進度、時長與選項 |
| [`policy`](docs/zh-Hant/policy.md) | 集中式跨模組播放器策略：跨模組行為規則的唯一事實來源 |
| [`pool`](docs/zh-Hant/pool.md) | 播放器實例池：實例分配、閒置回收、指標與狀態流 |
| [`preload`](docs/zh-Hant/preload.md) | 媒體預載：基於優先級的預載任務排程、預熱與生命週期管理 |
| [`presentation`](docs/zh-Hant/presentation.md) | 呈現模式：全螢幕、子母畫面與浮動視窗的 Redux 風格狀態機 |
| [`reactive`](docs/zh-Hant/reactive.md) | 響應式抽象與流工具：基於 rxdart 的共享工具箱 |
| [`reconciler`](docs/zh-Hant/reconciler.md) | 期望狀態與實際狀態調和：產生宣告式收斂動作計畫 |
| [`recording`](docs/zh-Hant/recording.md) | 錄製抽象：錄製會話、格式與後端 |
| [`recovery`](docs/zh-Hant/recovery.md) | 播放恢復：失敗後決定並排程恢復動作 |
| [`renderer`](docs/zh-Hant/renderer.md) | Flutter widget 層渲染抽象：surface、視圖、覆蓋層與渲染器狀態 |
| [`resource`](docs/zh-Hant/resource.md) | 資源管理：解碼器、記憶體、頻寬與溫度資源的預算、分域管理器與壓力計算 |
| [`result`](docs/zh-Hant/result.md) | 統一、不可變、基於值的結果型別：同步 Result、非同步 AsyncResult 與操作級 OperationResult |
| [`session`](docs/zh-Hant/session.md) | 播放會話：生命週期、上下文、狀態、事件與操作 |
| [`slot`](docs/zh-Hant/slot.md) | 邏輯播放器槽位：槽位所有權、分配與狀態 |
| [`source`](docs/zh-Hant/source.md) | 媒體來源抽象：描述、解析、探測、驗證與已解析中繼資料 |
| [`state_machine`](docs/zh-Hant/state_machine.md) | 通用領域無關狀態機基礎設施：狀態、事件、轉換與編排 |
| [`task`](docs/zh-Hant/task.md) | 可排程任務執行：任務值物件、優先級佇列、排程器與生命週期管理器 |
| [`util`](docs/zh-Hant/util.md) | 通用可重用靜態工具集：無領域邏輯、無跨模組依賴 |
| [`visibility`](docs/zh-Hant/visibility.md) | 播放器可見性觀察與管理：追蹤可見性並發出事件 |

### 快速開始

在 `pubspec.yaml` 中加入以下相依性，然後執行 `flutter pub get`：

```yaml
dependencies:
  media_core:
    git:
      url: https://github.com/liuchuancong/media_core.git
```

各模組的職責邊界、核心 API 與相依關係，請參閱上方「模組文件」逐一了解。

### 目錄結構

