# state_machine Module

> Generic, domain-agnostic state machine infrastructure: states, events, transitions, and orchestration.

## Module Responsibilities

- Provide a generic state machine (states + events + transition definitions + guards).
- The machine only executes transitions; the controller orchestrates around the machine at runtime (lifecycle, queue).

## Core API

| API | Description |
| --- | --- |
| `StateMachine<S>` | Owns transition execution only; no persistence/lifecycle/retry |
| `StateMachineController<S>` | Runtime orchestration: lifecycle and queue; does not replace the machine or implement retry policy |
| `StateMachineState` | Immutable state contract; no side effects |
| `StateMachineEvent` | Event value object |
| `StateTransition<S>` / `StateTransitionGuard<S>` | Transition definition / guard typedefs |
| `StateTransitionResult<S>` / `StateTransitionStatus` | Result of applying an event and status enum |
| `StateMachineContext` | Runtime execution context, extensible by domain modules |

## Design Notes

- Fully generic (no media-specific types); machine vs controller = execution vs orchestration. No cross-module imports.

## Dependencies

- No internal dependencies
