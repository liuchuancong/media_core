# slot Module

> Logical player slots: slot ownership, assignment, and state — mapping sessions/players onto a bounded set of player slots.

## Module Responsibilities

- Define logical slot entities, assignment records, and ownership semantics.
- Separated from physical player creation (`factory`/`session`) and the instance pool (`pool`).

## Core API

| API | Description |
| --- | --- |
| `PlayerSlot` | Logical slot entity |
| `PlayerSlotManager` | Slot lifecycle/assignment management; does not create players |
| `PlayerSlotAssignment` | Assignment record for slot↔session↔player |
| `PlayerSlotOwner` / `PlayerSlotOwnerType` | Ownership semantics and categories |
| `PlayerSlotState` / `PlayerSlotStatus` / `PlayerSlotSnapshot` | State / state enums / read-only snapshot |

## Design Notes

- Slot hierarchy: SlotId → PlayerId → SessionId (see the `identity` docs).

## Dependencies

- Internal: `identity` (SlotId, SessionId, PlayerId)
