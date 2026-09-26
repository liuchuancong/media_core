# reconciler Module

> Reconciliation of desired state and actual state (Kubernetes style): compares the two and produces a declarative convergence action plan, without executing any actions itself.

## Module Responsibilities

- `reconcile(current, desired)` → `ReconcilePlan` (e.g. gives `changeState` when the derived `PlayerStatus` is inconsistent).
- Queues and schedules plans, publishes reconciliation state; actual execution of actions belongs to Coordinator / Controller / SessionManager.

## Core API

| API | Description |
| --- | --- |
| `PlayerReconciler` | `reconcile(current, desired)`, `needsReconcile()`, `evaluate(plan)` → `ReconcileResult` (noop/pending) |
| `ReconcileAction` / `ReconcileActionType` | Purely descriptive actions (currently only `changeState`, with from/to states) |
| `ReconcilePlan` | Ordered action list; `empty()` factory |
| `ReconcileScheduler` | Queues plans, sorts execution order; publishes `ReconcileState` and a pending count via BehaviorSubject; does not execute actions |
| `ReconcileQueue` / `ReconcileState` / `ReconcileResult` / `ReconcileContext` | FIFO queue (skips empty plans) / running/completed/failed/pendingActions state / result / context |

## Design Notes

- Precedence for deriving `PlayerStatus` from `PlayerState` flags: disposed > disposing > opening > ….

## Dependencies

- Internal: `core` (PlayerState / PlayerStatus), `identity`
- External: `rxdart`, `equatable`
