# cache Module

> Generic two-level cache (memory + pluggable storage): eviction policies, expiration, metrics, and state tracking.

## Module Responsibilities

- Provide `CacheManager` to orchestrate L1 (in-memory `MemoryCache`) and L2 (`CacheStorage` persistence) together.
- Support pluggable eviction policies (LRU by default, plus FIFO) and per-entry expiration.
- Track metrics such as hit rate and operation counts, and expose a cache state stream.

## Core API

| API | Description |
| --- | --- |
| `CacheManager<T>` | High-level orchestrator: holds the policy, `CacheState`, and `CacheMetrics` |
| `CacheStorage<T>` | Persistence boundary interface: `read/write/remove/clear/contains/entries/dispose` |
| `MemoryCache<T>` | In-process storage: entry-count/byte caps + pluggable eviction; read touches the entry, expiration is lazily cleaned |
| `DiskCache` | JSON storage with one file per entry (`Uint8List` Base64); aimed at metadata/manifests/thumbnails, not large media payloads |
| `CacheEviction<T>` | Eviction interface; implementations: `LruCacheEviction`, `FifoCacheEviction` |
| `CacheEntry<T>` | Immutable entry: createdAt/accessedAt/expiresAt/sizeBytes, `touch()`, `isExpired` |
| `CacheKey` / `CacheResult<T>` | Key value object / sealed query result (hit/miss/expired) |
| `CacheMetrics` / `CacheState` | Metrics and state value objects |

## Design Notes

- Entries are storage-agnostic (the same `CacheEntry` can exist in memory and on disk at the same time).
- The `clock` package makes expiration logic testable.

## Dependencies

- External: `equatable`, `package:clock`, `dart:io` (DiskCache)
