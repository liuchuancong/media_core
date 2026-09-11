# util Module

> General-purpose, reusable static utility collection: a leaf module with no domain logic and no cross-module dependencies.

## Utilities at a Glance

| File | Description |
| --- | --- |
| `mime_utils.dart` | MIME lookup/normalization, isVideo/isAudio/isImage/isPlayable, extension mapping (most frequently used) |
| `duration_utils.dart` / `time_utils.dart` | Duration comparison/clamp/min/max, time formatting |
| `uri_utils.dart` / `cookie_utils.dart` / `header_utils.dart` | URI parsing/normalization, Cookie and HTTP header handling |
| `string_utils.dart` | String helpers |
| `enum_utils.dart` | Enum parsing/naming helpers (largest, 534 lines) |
| `future_utils.dart` / `stream_utils.dart` | Async/stream helpers (timeout, guard, logging wrapper) |
| `retry_utils.dart` / `dispose_utils.dart` | Retry helpers / safe disposal patterns |
| `debug_utils.dart` | `MediaCoreDebug`-style log/error/debugOnly/assertDebug/describe, etc. |
| `id_generator.dart` | ID generation |
| `map_utils.dart` / `list_utils.dart` / `math_utils.dart` / `validation_utils.dart` / `platform_utils.dart` | Collections, math, validation, and platform detection |

## Design Notes

- All are stateless static helper classes; an ideal leaf module that any module can depend on.
