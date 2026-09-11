# slot 模塊

> 邏輯播放器槽位:槽位的所有權、分配與狀態——把會話/播放器映射到一組有界的播放器槽位上。

## 模塊職責

- 定義邏輯槽位實體、分配記錄與所有權語義。
- 與物理播放器創建(`factory`/`session`)及實例池(`pool`)分離。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerSlot` | 邏輯槽位實體 |
| `PlayerSlotManager` | 槽位生命週期/分配管理;不創建播放器 |
| `PlayerSlotAssignment` | 槽位↔會話↔播放器的分配記錄 |
| `PlayerSlotOwner` / `PlayerSlotOwnerType` | 所有權語義與類別 |
| `PlayerSlotState` / `PlayerSlotStatus` / `PlayerSlotSnapshot` | 狀態 / 狀態枚舉 / 只讀快照 |

## 設計說明

- 槽位層級:SlotId → PlayerId → SessionId(見 `identity` 文檔)。

## 依賴

- 內部:`identity`(SlotId、SessionId、PlayerId)
