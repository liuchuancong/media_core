# util 模块

> 通用的可复用静态工具集：无领域逻辑、无跨模块依赖的叶子模块。

## 工具一览

| 文件 | 说明 |
| --- | --- |
| `mime_utils.dart` | MIME 查询/归一化、isVideo/isAudio/isImage/isPlayable、扩展名映射（使用频率最高） |
| `duration_utils.dart` / `time_utils.dart` | Duration 比较/clamp/min/max、时间格式化 |
| `uri_utils.dart` / `cookie_utils.dart` / `header_utils.dart` | URI 解析归一化、Cookie 与 HTTP 头处理 |
| `string_utils.dart` | 字符串辅助 |
| `enum_utils.dart` | 枚举解析/命名辅助（最大，534 行） |
| `future_utils.dart` / `stream_utils.dart` | 异步/流辅助（超时、守卫、日志包装） |
| `retry_utils.dart` / `dispose_utils.dart` | 重试辅助 / 安全释放模式 |
| `debug_utils.dart` | `MediaCoreDebug` 风格的 log/error/debugOnly/assertDebug/describe 等 |
| `id_generator.dart` | ID 生成 |
| `map_utils.dart` / `list_utils.dart` / `math_utils.dart` / `validation_utils.dart` / `platform_utils.dart` | 集合、数学、校验与平台判定 |

## 设计说明

- 全部为无状态静态辅助类；理想叶子模块，可被任何模块依赖。
