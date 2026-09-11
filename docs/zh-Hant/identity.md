# identity 模塊

> 跨模塊共享的強類型不可變標識值對象,讓各實體無需依賴字符串字段即可關聯。

## 模塊職責

- 定義七種平行 id 類型,形狀完全一致,全部 `final class ... extends Equatable implements Comparable`。
- `PlayerId` — 邏輯播放器實例
- `SessionId` — 一次播放會話(一個 player 可有多個)
- `SlotId` — 播放器池的資源槽(層級:SlotId → PlayerId → SessionId)
- `SourceId` — 邏輯媒體源;額外 `unknown()` 工廠與 `isUnknown`
- `OperationId` — 一個邏輯操作(open/play/seek/…)
- `RequestId` — 操作內一個具體請求(操作 : 請求 = 1 : N,對應重試/後端步驟)
- `GenerationId` — 生命週世代數,專門用於丟棄過期異步結果(詳見類文檔圖解)

## 通用 API(每個 id 類型一致)

- `X(value)` 工廠:trim 並在空串時拋 `ArgumentError`
- `X.generate()`:基於 `clock.now` 的時間戳+計數器(如 `player_<us>_<n>`),測試可控
- `parse` / `isValid` / `fromJson` / `toJson`(原始字符串)
- `isSameAs` / `isDifferentFrom` / `compareTo`

## 設計說明

- 基礎層模塊,僅依賴外部包。
- `identity_json_converters.dart` 提供各 id 的 `JsonConverter`,供 json_serializable 集成。

## 依賴

- 外部:`equatable`、`clock`、`json_annotation`
