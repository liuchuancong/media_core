# event 模塊

> 播放器事件的定義、總線與分發:只負責事件傳輸,不含任何業務邏輯。

## 模塊職責

- 定義 media core 對外發出的不可變事件值。
- 提供中心事件總線與分發器,支持過濾訂閱與一次性直達投遞。
- 攜帶關聯元數據(`EventContext`),便於跨模塊追蹤。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerEvent` | sealed 事件基類:攜帶 `type`、可選 `EventContext`、`priority`;子類含 `GenericPlayerEvent`、`PlayerErrorEvent`、`PlayerLifecycleEvent` |
| `PlayerEventBus` | 廣播總線:`publish/publishAll`、`subscribe/subscribeOnce`、`next(filter)`、`dispose`;內部委託 `EventDispatcher` |
| `EventDispatcher` | 註冊過濾訂閱;`dispatchTo` 一次性直達投遞;`cancelAll`、`dispose` |
| `EventContext` | 關聯元數據(playerId/sessionId/slotId/sourceId/operationId/requestId/generationId + metadata + 時間戳) |
| `EventFilter` | 過濾器接口;實現:`AllowAllEventFilter`、`EventTypeFilter`、`EventPriorityFilter`、`EventContextFilter`、`CompositeEventFilter`(可組合) |
| `EventPriority` / `EventPriorityValue` | 優先級枚舉(low/normal/high/critical)與排序包裝 |
| `PlayerEventType` | 17 個事件類別枚舉(player、session、source、playback、buffering、renderer、audio、presentation、recovery、fallback、cache、recording、visibility、lifecycle、error、diagnostics、unknown) |

## 設計說明

- 事件是不可變值;總線/分發器只管傳輸;訂閱(`EventSubscription`)只管投遞配置(暫停/恢復/取消)。

## 依賴

- 內部:`identity`(全部七種 id)
- 外部:`clock`、`equatable`
