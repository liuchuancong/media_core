# source 模塊

> 媒體源抽象:源的描述、解析、探測、校驗,以及產出可供播放設置的已解析元數據。

## 模塊職責

- 以 `PlayerSource` / `SourceDescriptor` / `ResolvedSource` 三段式建模源的聲明、描述與解析結果。
- 以職責鏈模式組合多個解析器(`SourceResolverChain`)與探測器(`SourceInspectorChain`)。
- `SourceService` 作為門面完成「解析 + 探測」,不做生命週期/重試/降級/後端選擇。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerSource` | 核心源值對象(freezed 抽象);解析/探測屬本層,後端播放屬適配器 |
| `SourceDescriptor` | 遞交給解析器/探測器/適配器的描述性載荷(freezed) |
| `ResolvedSource` | 已解析、可供播放設置的輸出(freezed) |
| `SourceService` / `SourceRegistry` | 門面(返回 `SourceInspectionResult`)/ 註冊解析器與探測器並組裝 Service |
| `SourceResolver` / `SourceResolverChain` / `SourceInspector` / `SourceInspectorChain` | 職責鏈模式的解析與探測,附 `SourceResolveContext` / `SourceInspectContext` |
| `SourceValidator` / `SourceValidationResult` / `SourceValidationException` | 校驗 |
| `SourceIdentity` / `SourceLocation` / `SourceMetadata` / `SourceRequest` / `SourceHeaders` | 支撐值對象(多為 freezed) |
| `SourceProtocol` / `SourceMediaType` / `SourceType` / `SourceFormat` | 協議/媒體類型/源類型/格式枚舉 |

## 依賴

- 內部:`identity`(SourceId、RequestId)、`core`(player_info.dart)
