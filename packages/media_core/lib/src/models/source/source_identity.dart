import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/source_id.dart';

part 'source_identity.g.dart';

/// Describes the identity information of a media source.
///
/// [SourceIdentity] provides the source-level identity used during
/// resolving and playback — the provider it came from, the id the provider
/// knows it by, and a human-readable name.
///
/// Difference from [SourceId]:
///
/// - [SourceId]: global identifier used across modules.
/// - [SourceIdentity]: descriptive identity information of a source.
///
/// Responsibilities:
///
/// - describe source identity
/// - store human-readable identifiers
///
/// It does not:
///
/// - generate identifiers
/// - manage lifecycle
/// - persist data
///
/// Those belong to:
///
/// - the identity module
/// - the storage layer
abstract class SourceIdentity implements Built<SourceIdentity, SourceIdentityBuilder> {
  /// Builds an identity from a [updates] callback — the codegen entry.
  factory SourceIdentity([void Function(SourceIdentityBuilder)? updates]) = _$SourceIdentity;

  /// Creates an identity from the fields it describes.
  factory SourceIdentity.of({
    required SourceId id,
    String? provider,
    String? externalId,
    String? name,
    String? namespace,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return SourceIdentity(
      (builder) => builder
        ..id = id
        ..provider = provider
        ..externalId = externalId
        ..name = name
        ..namespace = namespace
        ..attributes = attributes,
    );
  }

  SourceIdentity._();

  /// Creates an unknown identity.
  factory SourceIdentity.unknown() => SourceIdentity.of(id: SourceId.unknown());

  /// Carries no attributes unless the caller supplies them.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(SourceIdentityBuilder builder) => builder..attributes = const <String, Object?>{};

  /// Global source identifier.
  SourceId get id;

  /// Provider identifier, for example `youtube`, `bilibili` or `custom`.
  String? get provider;

  /// External source identifier: a channel id, room id or media id.
  String? get externalId;

  /// Human-readable name.
  String? get name;

  /// Optional namespace, for example `user`, `platform` or `service`.
  String? get namespace;

  /// Additional identity attributes.
  Map<String, Object?> get attributes;
}

/// Extensions for [SourceIdentity].
extension SourceIdentityExtension on SourceIdentity {
  /// Whether identity is known.
  bool get isKnown {
    return id != SourceId.unknown();
  }

  /// Whether external identity exists.
  bool get hasExternalId {
    return externalId != null && externalId!.isNotEmpty;
  }

  /// Whether provider exists.
  bool get hasProvider {
    return provider != null && provider!.isNotEmpty;
  }

  /// Creates identity with one attribute set.
  SourceIdentity putAttribute(String key, Object? value) {
    return rebuild((builder) => builder..attributes = <String, Object?>{...attributes, key: value});
  }
}
