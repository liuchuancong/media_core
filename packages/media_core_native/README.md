# media_core_native

> media_core 的原生平台插件(聯邦式 plugin):提供主包所需的原生能力入口。

## 定位

[media_core](../media_core) 主包刻意與平台解耦(見 `platform`、`audio` 等模塊的接口定義)。本包承擔各平台的原生實現,例如:

- 音頻焦點 / 音頻會話(`audio` 模塊的 `AudioFocus` / `AudioSession` 接口)
- 平台能力查詢(`platform` 模塊的 `PlatformProvider` 接口)
- 呈現適配(`presentation` 模塊的 `PresentationAdapter`:系統級 PiP 等)

## 代碼結構

| 文件 | 說明 |
| --- | --- |
| `lib/media_core_native.dart` | 對外門面(當前僅 `getPlatformVersion()`) |
| `lib/media_core_native_platform_interface.dart` | 平台接口(帶 token 校驗的 `instance` 設置,便於測試替換) |
| `lib/media_core_native_method_channel.dart` | MethodChannel(`media_core_native`)默認實現 |

## 平台支持

⚠️ 暫無:pubspec 的 plugin 段仍為佔位(`some_platform`),尚未添加 android/ios 等平台目錄。

## Example

見 [example/](example/):演示調用 `getPlatformVersion()`。添加平台實現後可在此驗證。

## 相關文檔

- 主包架構:`packages/media_core/media_core_architecture_guide.md`
- 平台抽象:`packages/media_core/lib/platform/README.md`
- 音頻抽象:`packages/media_core/lib/audio/README.md`
