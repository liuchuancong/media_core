# util 模塊

> 通用的可複用靜態工具集:無領域邏輯、無跨模塊依賴的葉子模塊。

## 工具一覽

| 文件 | 說明 |
| --- | --- |
| `mime_utils.dart` | MIME 查詢/歸一化、isVideo/isAudio/isImage/isPlayable、擴展名映射(使用頻率最高) |
| `duration_utils.dart` / `time_utils.dart` | Duration 比較/clamp/min/max、時間格式化 |
| `uri_utils.dart` / `cookie_utils.dart` / `header_utils.dart` | URI 解析歸一化、Cookie 與 HTTP 頭處理 |
| `string_utils.dart` | 字符串輔助 |
| `enum_utils.dart` | 枚舉解析/命名輔助(最大,534 行) |
| `future_utils.dart` / `stream_utils.dart` | 異步/流輔助(超時、守衛、日誌包裝) |
| `retry_utils.dart` / `dispose_utils.dart` | 重試輔助 / 安全釋放模式 |
| `debug_utils.dart` | `MediaCoreDebug` 風格的 log/error/debugOnly/assertDebug/describe 等 |
| `id_generator.dart` | ID 生成 |
| `map_utils.dart` / `list_utils.dart` / `math_utils.dart` / `validation_utils.dart` / `platform_utils.dart` | 集合、數學、校驗與平台判定 |

## 設計說明

- 全部為無狀態靜態輔助類;理想葉子模塊,可被任何模塊依賴。
