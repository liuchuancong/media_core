# bug Module

> Debugging and fault-injection infrastructure: bug modes, fault configuration, hooks, injectors, schedulers, and scenarios for testing player resilience.

## Module Responsibilities

- Provide `BugMode` severity levels (disabled/safe/normal/aggressive/chaos) to control fault-injection permissions.
- Describe a single injection declaratively with `FaultConfig` (type, probability, delay, duration, max count).
- Execute fault behavior inside modules through `BugHook` injection points and record `FaultEvent`.
- Support repeatable fault scenarios (`FaultScenario`).

## Core API

| API | Description |
| --- | --- |
| `BugMode` / `BugModeConfig` / `BugModeController` | Fault-mode value object + immutable config + mutable runtime controller (broadcasts a config stream, decides permissions) |
| `BugHook` / `BugHooks` | Module-level hook interface and registry: decides whether a given `FaultConfig` is supported and executes the fault |
| `FaultType` | Extensible semantic fault-type value object |
| `FaultConfig` | Description of one injection; provides `deterministic` / `random` probability constructors |
| `FaultInjector` | Coordinates permission checks, active-fault registration, fault ID generation, hook selection, and event creation |
| `FaultScheduler` | Timing only: `schedule` / `scheduleDelayed` / `scheduleScenario` |
| `FaultScenario` / `FaultEvent` | Named, repeatable fault collection / record of an injected fault |

## Design Notes

- Layered pipeline: FaultScenario/FaultScheduler → FaultInjector → BugHook; each layer's docs explicitly note what it "does not do" (permission vs timing vs execution).

## Dependencies

- External: `equatable`, `package:clock` (test-friendly time)
