# coordinator 模塊

> 跨模塊協調層:按 `PlayerId` 將播放器綁定到各子系統控制器/管理器,並在它們之間轉發請求;自身不執行任何操作。

## 模塊職責

- 作為組合根(`GlobalPlayerCoordinator`)聚合播放、頁面、音頻、資源、預載、生命週期與呈現協調器。
- 統一採用「註冊/註銷/查找 + `request(...)` 轉發」的模式,把請求路由到對應子系統。
- 不創建播放器、不調用平台 API、不保存播放狀態。

## 核心 API

| API | 說明 |
| --- | --- |
| `GlobalPlayerCoordinator` | 根組合:聚合下列各協調器(均可惰性給默認值) |
| `PlaybackCoordinator` | 每播放器綁定 `PlaybackController`,轉發 `PlaybackRequest` |
| `PlayerCoordinator` | 綁定 `Player`/`PlayerSession` 對,承擔高層播放器工作流 |
| `PlayerAudioCoordinator` | 註冊每播放器的 `AudioManager`;每播放器音量/靜音與響應式流;操作串行化、銷毀冪等 |
| `LifecycleCoordinator` | 每播放器綁定 `PlayerLifecycle` 處理器,分發生命週期事件 |
| `PageCoordinator` | 頁面↔播放器綁定(`attachPlayer/detachPlayer`、活躍頁面) |
| `PreloadCoordinator` | 每播放器綁定 `PreloadManager`,轉發預載請求 |
| `ResourceCoordinator` | 每播放器綁定 `ResourceManager`,應用資源壓力決策 |
| `PresentationCoordinator` | 每播放器綁定 `PresentationController`,路由呈現請求 |

## 設計說明

- 協調器永遠只是「綁定 + 轉發」;實際職責分屬 PlayerFactory / PlayerAdapter / PlaybackController 等。
- 適合在應用層通過 `GlobalPlayerCoordinator` 統一拿各子系統入口。

## 依賴

- 內部:`identity`、`core`、`session`、`playback`、`audio`、`lifecycle`、`preload`、`presentation`、`resource`
- 外部:`rxdart`
