# danmaku module

> Danmaku sessions: a platform-agnostic transport contract, message normalization, backlog/duplicate gating, content filtering, and session fencing.

## Responsibilities

- Own exactly one room-bound danmaku session: install/replace the transport, connect, stop, and recover.
- Serialize every connect/stop transition and guard callbacks with a session token, so an old socket can never write into a new room.
- Run the message pipeline: gate (duplicates/backlog) → block policy → repeated-text filter → similarity filter.
- Expose session state and a failure stream for the host to observe.

## Core API

| API | Description |
| --- | --- |
| `DanmakuController` | Session orchestration root: `installTransport` / `replaceTransport` / `connect` / `stop` / `recover`, plus state and failure streams |
| `DanmakuTransport` | Platform contract: `start(request, listener)` / `stop()` / `heartbeat()` / `isConnected` / `heartbeatInterval`; single-room, single-use |
| `DanmakuTransportListener` | Transport → session callbacks: message, ready, reconnecting, closed |
| `DanmakuTransportRequest` / `DanmakuRoomRef` / `DanmakuAuth` | Connection inputs: room, credentials, and platform-specific `extras` |
| `DanmakuSink` | Output port: messages, audience metrics, paid messages, notices, room id, clear — implemented by the host |
| `DanmakuMessage` / `DanmakuMessageType` / `DanmakuColor` / `DanmakuStyle` | Normalized message model |
| `DanmakuSuperChat` / `DanmakuAudienceUpdate` / `DanmakuAudienceKind` | Paid-message and audience payloads |
| `DanmakuMessageGate` | Duplicate and backlog gate: long window for stable ids, short fingerprint window without ids, age limit, bounded eviction |
| `DanmakuRepeatedFilter` | Collapses identical text in a short burst (across accounts); local messages are exempt |
| `DanmakuSimilarityFilter` | Fuzzy suppression with a separate retained cache and comparison budget |
| `DanmakuFilterPolicy` | Viewer-level blocking: users and keywords, normalized on construction |
| `DanmakuConfig` | Every tunable; defaults are the reference implementation's tuned values |
| `DanmakuSessionState` / `DanmakuSessionPhase` | Session snapshot and lifecycle phase |
| `DanmakuFailure` / `DanmakuFailureKind` | Failure model (kept apart from playback failures) |

## Design notes

- **Layer discipline**: the module only decodes, deduplicates, filters, and manages lifecycle. Adapter packages implement `DanmakuTransport` for platforms; the host implements `DanmakuSink` for rendering, queueing, and wording. No platform is known here.
- **Session fencing**: every accepted session increments a token, and the listener handed to a transport captures the triple (transport identity, room key, token). A callback that fails any part of the match is dropped. This replaces mutable callback fields: a transport cannot swap the listener mid-flight.
- **Serialized transitions**: room switches, setting changes, player reloads, and floating-window teardown can land in the same event-loop turn. Every transition is appended to one operation tail and re-checks a request epoch before acting, so two handshakes never race for the same room.
- **Locally settled sessions**: a platform without chat support is expressed by a transport that reports readiness without opening a socket. That session counts as established and stops being retried, so "unsupported" needs no state of its own.
- **Pipeline order**: gate → policy → repeated → similarity. The gate and policy are the cheapest and most decisive, so they reject most traffic first; similarity is the most expensive step and therefore runs last, with a comparison budget. The viewer's own echo bypasses similarity (they must see what they sent) but not the gate or the policy.
- **The window is anchored at first arrival**: a rejected repeat does not extend it. A socket flapping for an hour must not keep one message id suppressed for an hour — the duplicate window only has to outlast a reconnect replay.
- **Notices are codes, not sentences**: the module has no locale. `DanmakuNotice` reports facts; the host owns wording and whether to show anything.
- **Heartbeat ownership**: the session schedules keep-alives from `heartbeatInterval`, so a transport needs no timer of its own. A transport that manages its own heartbeat reports `Duration.zero` and is left alone.

## Dependencies

- Internal: `diagnostics` (structured logging, `LogCategory.danmaku`)
- External: `rxdart` (state/failure streams), `fuzzywuzzy` (similarity scoring)
