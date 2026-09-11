# audio 模塊

> 平台無關的音頻子系統管理:音頻焦點(Audio Focus)、音頻會話(Session)、輸出路由、音量與靜音。

## 模塊職責

- 管理音頻子系統的高層生命週期:激活/去激活(先會話後焦點,失敗自動回滾)。
- 以響應式流暴露 `enabled` / `active` / `focused` 狀態。
- 將 Android 焦點、iOS AVAudioSession 打斷等平台細節隱藏在接口之後。

## 核心 API

| API | 說明 |
| --- | --- |
| `AudioManager` | 高層門面:`activate/deactivate`、`abandonFocus/requestFocus`、`setEnabled`,冪等 `dispose` |
| `AudioCoordinator` | 協調層:把焦點+會話整合為 `AudioFocusState` / `AudioSessionState` 流;以單調 `generation` 計數拒絕過期的異步平台回調 |
| `AudioFocus` / `AudioSession` | 平台抽象接口(實現由平台適配層提供) |
| `AudioRoute` / `AudioRouteKind` | 輸出路由的粗粒度描述(揚聲器等) |
| `AudioVolume` / `AudioMute` | 歸一化音量(0.0–1.0)與靜音值對象 |
| `AudioFocusState` / `AudioSessionState` | 不可變狀態快照 |

## 設計說明

- 所有生命週期操作通過鏈式 future 隊列串行化,防止競態。
- 職責分層清晰:Focus/Session 是平台接縫,Coordinator 整合狀態,Manager 對外。

## 依賴

- 外部:`rxdart`(BehaviorSubject / ValueStream)、`equatable`
