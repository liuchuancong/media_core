# source 模块

> 媒体源抽象：源的描述、解析、探测、校验，以及产出可供播放设置的已解析元数据。

## 模块职责

- 以 `PlayerSource` / `SourceDescriptor` / `ResolvedSource` 三段式建模源的声明、描述与解析结果。
- 以职责链模式组合多个解析器（`SourceResolverChain`）与探测器（`SourceInspectorChain`）。
- `SourceService` 作为门面完成「解析 + 探测」，不做生命周期/重试/降级/后端选择。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerSource` | 核心源值对象（freezed 抽象）；解析/探测属本层，后端播放属适配器 |
| `SourceDescriptor` | 递交给解析器/探测器/适配器的描述性载荷（freezed） |
| `ResolvedSource` | 已解析、可供播放设置的输出（freezed） |
| `SourceService` / `SourceRegistry` | 门面（返回 `SourceInspectionResult`）/ 注册解析器与探测器并组装 Service |
| `SourceResolver` / `SourceResolverChain` / `SourceInspector` / `SourceInspectorChain` | 职责链模式的解析与探测，附 `SourceResolveContext` / `SourceInspectContext` |
| `SourceValidator` / `SourceValidationResult` / `SourceValidationException` | 校验 |
| `SourceIdentity` / `SourceLocation` / `SourceMetadata` / `SourceRequest` / `SourceHeaders` | 支撑值对象（多为 freezed） |
| `SourceProtocol` / `SourceMediaType` / `SourceType` / `SourceFormat` | 协议/媒体类型/源类型/格式枚举 |

## 依赖

- 内部：`identity`（SourceId、RequestId）、`core`（player_info.dart）
