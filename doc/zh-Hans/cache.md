# cache 模块

> 通用二级缓存（内存 + 可插拔存储）：驱逐策略、过期、指标与状态跟踪。

## 模块职责

- 提供 `CacheManager` 统一编排 L1（内存 `MemoryCache`）与 L2（`CacheStorage` 持久化）。
- 支持可插拔驱逐策略（默认 LRU，另有 FIFO）与按条目过期。
- 统计命中率、操作数等指标并暴露缓存状态流。

## 核心 API

| API | 说明 |
| --- | --- |
| `CacheManager<T>` | 高层编排器：持有策略、`CacheState` 与 `CacheMetrics` |
| `CacheStorage<T>` | 持久化边界接口：`read/write/remove/clear/contains/entries/dispose` |
| `MemoryCache<T>` | 进程内存储：条目数/字节上限 + 可插拔驱逐；读取即 touch，过期惰性清除 |
| `DiskCache` | 每条目一文件的 JSON 存储（`Uint8List` Base64）；面向元数据/清单/缩略图，不适合大媒体负载 |
| `CacheEviction<T>` | 驱逐接口；实现：`LruCacheEviction`、`FifoCacheEviction` |
| `CacheEntry<T>` | 不可变条目：createdAt/accessedAt/expiresAt/sizeBytes，`touch()`、`isExpired` |
| `CacheKey` / `CacheResult<T>` | 键值对象 / sealed 查询结果（hit/miss/expired） |
| `CacheMetrics` / `CacheState` | 指标与状态值对象 |

## 设计说明

- 条目与存储无关（同一 `CacheEntry` 可同时存在于内存与磁盘）。
- 使用 `clock` 包使过期逻辑可测试。

## 依赖

- 外部：`equatable`、`package:clock`、`dart:io`（DiskCache）
