# event Module

> Definition, bus, and dispatch of player events: responsible only for event transport, with no business logic.

## Module Responsibilities

- Define the immutable event values emitted outward by media core.
- Provide a central event bus and dispatcher supporting filtered subscriptions and one-shot direct delivery.
- Carry associated metadata (`EventContext`) for cross-module tracing.

## Core API

| API | Description |
| --- | --- |
| `PlayerEvent` | Sealed event base class: carries `type`, optional `EventContext`, `priority`; subclasses include `GenericPlayerEvent`, `PlayerErrorEvent`, `PlayerLifecycleEvent` |
| `PlayerEventBus` | Broadcast bus: `publish/publishAll`, `subscribe/subscribeOnce`, `next(filter)`, `dispose`; internally delegates to `EventDispatcher` |
| `EventDispatcher` | Registers filtered subscriptions; `dispatchTo` does one-shot direct delivery; `cancelAll`, `dispose` |
| `EventContext` | Associated metadata (playerId/sessionId/slotId/sourceId/operationId/requestId/generationId + metadata + timestamp) |
| `EventFilter` | Filter interface; implementations: `AllowAllEventFilter`, `EventTypeFilter`, `EventPriorityFilter`, `EventContextFilter`, `CompositeEventFilter` (composable) |
| `EventPriority` / `EventPriorityValue` | Priority enum (low/normal/high/critical) and ordering wrapper |
| `PlayerEventType` | Enum of 17 event categories (player, session, source, playback, buffering, renderer, audio, presentation, recovery, fallback, cache, recording, visibility, lifecycle, error, diagnostics, unknown) |

## Design Notes

- Events are immutable values; the bus/dispatcher only transport; subscriptions (`EventSubscription`) only configure delivery (pause/resume/cancel).

## Dependencies

- Internal: `identity` (all seven kinds of ids)
- External: `clock`, `equatable`
