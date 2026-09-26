# source Module

> Media source abstraction: source declaration, resolution, inspection, validation, and resolved metadata ready for playback setup.

## Module Responsibilities

- Model source declaration, description, and resolution results in three stages with `PlayerSource` / `SourceDescriptor` / `ResolvedSource`.
- Combine multiple resolvers (`SourceResolverChain`) and inspectors (`SourceInspectorChain`) using the chain-of-responsibility pattern.
- `SourceService` acts as a facade completing "resolution + inspection"; it does not handle lifecycle/retry/fallback/backend selection.

## Core API

| API | Description |
| --- | --- |
| `PlayerSource` | Core source value object (freezed abstract); resolution/inspection belong to this layer, backend playback belongs to the adapter |
| `SourceDescriptor` | Descriptive payload submitted to resolvers/inspectors/adapters (freezed) |
| `ResolvedSource` | Resolved output ready for playback setup (freezed) |
| `SourceService` / `SourceRegistry` | Facade (returns `SourceInspectionResult`) / registers resolvers and inspectors and assembles the Service |
| `SourceResolver` / `SourceResolverChain` / `SourceInspector` / `SourceInspectorChain` | Chain-of-responsibility resolution and inspection, with `SourceResolveContext` / `SourceInspectContext` |
| `SourceValidator` / `SourceValidationResult` / `SourceValidationException` | Validation |
| `SourceIdentity` / `SourceLocation` / `SourceMetadata` / `SourceRequest` / `SourceHeaders` | Supporting value objects (mostly freezed) |
| `SourceProtocol` / `SourceMediaType` / `SourceType` / `SourceFormat` | Protocol/media type/source type/format enums |

## Dependencies

- Internal: `identity` (SourceId, RequestId), `core` (player_info.dart)
