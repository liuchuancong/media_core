# reconciler 模塊

> 期望狀態與實際狀態的調和(Kubernetes 風格):比較兩者並產生宣告式的收斂動作計劃,自身不執行任何動作。

## 模塊職責

- `reconcile(current, desired)` → `ReconcilePlan`(如派生 `PlayerStatus` 不一致時給出 `changeState`)。
- 排隊與調度計劃,發布調和狀態;動作的實際執行屬於 Coordinator / Controller / SessionManager。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerReconciler` | `reconcile(current, desired)`、`needsReconcile()`、`evaluate(plan)` → `ReconcileResult`(noop/pending) |
| `ReconcileAction` / `ReconcileActionType` | 純描述性動作(目前僅 `changeState`,含 from/to 狀態) |
| `ReconcilePlan` | 有序動作列表;`empty()` 工廠 |
| `ReconcileScheduler` | 計劃排隊、排序執行順序;BehaviorSubject 發布 `ReconcileState` 與 pending 計數;不執行動作 |
| `ReconcileQueue` / `ReconcileState` / `ReconcileResult` / `ReconcileContext` | FIFO 隊列(跳過空計劃)/ running/completed/failed/pendingActions 狀態 / 結果 / 上下文 |

## 設計說明

- 從 `PlayerState` 旗標解析 `PlayerStatus` 的優先級:disposed > disposing > opening > …。

## 依賴

- 內部:`core`(PlayerState / PlayerStatus)、`identity`
- 外部:`rxdart`、`equatable`
