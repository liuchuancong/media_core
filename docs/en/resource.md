# resource Module

> Resource management: budgets for decoder, memory, bandwidth, and thermal resources, per-domain managers, pressure calculation, and the central ResourceManager.

## Module Responsibilities

- Each domain manager produces a usage snapshot and computes resource pressure against budgets.
- `ResourceManager` aggregates per-domain pressure and produces a `ResourceSnapshot` (pressure may trigger higher-level decisions such as lowering quality, stopping preload, or switching streams).

## Core API

| API | Description |
| --- | --- |
| `ResourceManager` | Central aggregator: consumes per-domain pressure, produces `ResourceSnapshot` |
| `DecoderManager` / `MemoryManager` / `BandwidthManager` / `ThermalManager` | Four per-domain managers, each with its own usage snapshot (`XUsageSnapshot` / `ThermalSnapshot`) |
| `DecoderBudget` / `MemoryBudget` / `BandwidthBudget` | Allocation caps and validation |
| `ResourcePressure` / `ResourcePressureSnapshot` | Pressure enum and pressure snapshot, fed to ResourceManager |
| `ThermalState` / `ResourcePriority` / `ResourceState` / `ResourceMetrics` / `ResourceSnapshot` | Thermal state / priority / state / metrics / read-only overview snapshot (for UI/debug/metrics) |

## Design Notes

- Flow (ASCII diagram in the source): manager → budget → pressure → ResourceManager → snapshot; snapshots are read-only views and do not execute operations.

## Dependencies

- Internal: `policy` (resource_policy.dart)
