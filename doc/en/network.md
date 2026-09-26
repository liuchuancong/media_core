# network Module

> Network abstraction: connectivity state/condition/type/quality modeling, performance metrics, and request/response execution; monitoring is delegated to the platform adapter layer.

## Module Responsibilities

- Provide platform-agnostic network models (state, condition, type, quality) and performance metrics.
- Define an injectable request-executor interface; it does not measure bandwidth, ping, or do IO itself.

## Core API

| API | Description |
| --- | --- |
| `NetworkManager` | Main entry point: holds a `NetworkMonitor`, exposes `state/condition/metrics` and their streams, `start/stop`, `request(NetworkRequest)` |
| `NetworkMonitor` / `BaseNetworkMonitor` | Abstract monitoring interface + broadcast-stream base class; subclasses override `onStart/onStop` and push updates via protected methods `updateState/updateCondition/updateMetrics` |
| `NetworkCondition` | freezed: connected, type, quality, up/down bandwidth, latency, metered, expensive; extensions `isAvailable/isFast/hasLatency` |
| `NetworkState` | connected/type/quality/metered/expensive/updatedAt |
| `NetworkMetrics` | latency min/avg/max, throughput, request/byte counts; `failureRate`, `hasHighFailureRate`, `isHealthy` |
| `NetworkRequest` / `NetworkResponse` | Request (uri, method, `SourceHeaders`, body, timeout, maxRetries, cacheable) and response (statusCode, data, headers, duration, fromCache, `isSuccess`) |
| `NetworkType` / `NetworkQuality` | Enums: unknown/none/ethernet/wifi/mobile/bluetooth/vpn/other; unknown/unavailable/poor/fair/good/excellent (`isUsable/isStable/score 0–5`) |

## Design Notes

- Pure data-model layer; http/dio/platform adapters are plugged in through an injected executor.

## Dependencies

- Internal: `source` (SourceHeaders)
- External: `freezed` / `freezed_annotation`
