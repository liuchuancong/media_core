# identity Module

> Strongly-typed, immutable identifier value objects shared across modules so entities can relate without depending on string fields.

## Module Responsibilities

- Define seven parallel id types with identical shapes, all `final class ... extends Equatable implements Comparable`.
- `PlayerId` — a logical player instance
- `SessionId` — one playback session (a player may have several)
- `SlotId` — a resource slot in the player pool (hierarchy: SlotId → PlayerId → SessionId)
- `SourceId` — a logical media source; additionally `unknown()` factory and `isUnknown`
- `OperationId` — one logical operation (open/play/seek/…)
- `RequestId` — one concrete request within an operation (operation : request = 1 : N, corresponding to retry/backend steps)
- `GenerationId` — lifecycle generation, used specifically to discard stale async results (see the diagram in the class docs)

## Common API (identical for every id type)

- `X(value)` factory: trims and throws `ArgumentError` on an empty string
- `X.generate()`: timestamp+counter based on `clock.now` (e.g. `player_<us>_<n>`), test-controllable
- `parse` / `isValid` / `fromJson` / `toJson` (raw string)
- `isSameAs` / `isDifferentFrom` / `compareTo`

## Design Notes

- Foundation-layer module depending only on external packages.
- `identity_json_converters.dart` provides a `JsonConverter` for each id for json_serializable integration.

## Dependencies

- External: `equatable`, `clock`, `json_annotation`
