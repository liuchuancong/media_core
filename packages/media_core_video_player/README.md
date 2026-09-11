# media_core_video_player

> 基於 Flutter 官方 [video_player](https://pub.dev/packages/video_player) 插件的 media_core 播放後端適配器。

## 定位

本包為 [media_core](../media_core) 提供以 Flutter 官方 `video_player` 為引擎的輕量後端實現,目標是實現主包 `adapter` 模塊定義的合約:

- `PlayerAdapter` —— 統一的播放後端合約(打開/播放/暫停/seek/音量/速率/關閉,狀態與事件流)
- `PlayerAdapterFactory` —— 適配器創建工廠,註冊後參與後端選擇與降級候選排序

適用場景:只需基礎播放能力、希望減少原生依賴體積的應用;可與 `media_core_media_kit` 並存,由 `BackendSelector` 按能力與優先級選用。

## 平台支持

跟隨 video_player:Android、iOS、Web(Windows/macOS 需平台視圖支持)。

## 當前狀態

⚠️ **尚未實現**:目前僅為腳手架模板,依賴已聲明 `video_player` 與 `media_core`(path 依賴),適配器尚未編寫。

## 相關文檔

- 適配器合約:`packages/media_core/lib/adapter/README.md`
- 後端註冊與選擇:`packages/media_core/lib/factory/README.md`
