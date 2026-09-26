# cache 模塊

> 通用二級緩存(內存 + 可插拔存儲):驅逐策略、過期、指標與狀態跟蹤。

## 模塊職責

- 提供 `CacheManager` 統一編排 L1(內存 `MemoryCache`)與 L2(`CacheStorage` 持久化)。
- 支持可插拔驅逐策略(默認 LRU,另有 FIFO)與按條目過期。
- 統計命中率、操作數等指標並暴露緩存狀態流。

## 核心 API

| API | 說明 |
| --- | --- |
| `CacheManager<T>` | 高層編排器:持有策略、`CacheState` 與 `CacheMetrics` |
| `CacheStorage<T>` | 持久化邊界接口:`read/write/remove/clear/contains/entries/dispose` |
| `MemoryCache<T>` | 進程內存儲:條目數/字節上限 + 可插拔驅逐;讀取即 touch,過期惰性清除 |
| `DiskCache` | 每條目一文件的 JSON 存儲(`Uint8List` Base64);面向元數據/清單/縮略圖,不適合大媒體負載 |
| `CacheEviction<T>` | 驅逐接口;實現:`LruCacheEviction`、`FifoCacheEviction` |
| `CacheEntry<T>` | 不可變條目:createdAt/accessedAt/expiresAt/sizeBytes,`touch()`、`isExpired` |
| `CacheKey` / `CacheResult<T>` | 鍵值對象 / sealed 查詢結果(hit/miss/expired) |
| `CacheMetrics` / `CacheState` | 指標與狀態值對象 |

## 設計說明

- 條目與存儲無關(同一 `CacheEntry` 可同時存在內存與磁盤)。
- 使用 `clock` 包使過期邏輯可測試。

## 依賴

- 外部:`equatable`、`package:clock`、`dart:io`(DiskCache)
