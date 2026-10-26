import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/audio/audio_route_kind.dart' show AudioRouteKind;

part 'audio_route.g.dart';

/// Identifies the logical audio output route used by the media session.
///
/// This is a platform-independent value object. Native route identifiers
/// should not leak into the media core because their representation differs
/// across Android, iOS, macOS, Windows, Linux, and other platforms.
///
/// A route may represent a physical output device, a platform-managed output
/// group, or the system's default route.
abstract class AudioRoute implements Built<AudioRoute, AudioRouteBuilder> {
  /// Builds AudioRoute from a [updates] callback — the codegen entry.
  factory AudioRoute([void Function(AudioRouteBuilder)? updates]) = _$AudioRoute;

  /// Creates an audio route.
  ///
  /// [id] must uniquely identify the route within the owning platform audio
  /// implementation. [name] is intended for presentation and diagnostics and
  /// should therefore not be used as the route's identity.
  factory AudioRoute.of({
    required String id,
    required String name,
    AudioRouteKind kind = AudioRouteKind.unknown,
    bool isDefault = false,
    bool isAvailable = true,
  }) {
    return AudioRoute(
      (builder) => builder
        ..id = id
        ..name = name
        ..kind = kind
        ..isDefault = isDefault
        ..isAvailable = isAvailable,
    );
  }

  AudioRoute._();

  /// A route the platform described without a category or availability is
  /// still a route it can play through.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(AudioRouteBuilder builder) => builder
    ..kind = AudioRouteKind.unknown
    ..isDefault = false
    ..isAvailable = true;

  /// Stable identifier supplied by the platform audio implementation.
  String get id;

  /// Human-readable route name.
  String get name;

  /// Logical type of the route.
  AudioRouteKind get kind;

  /// Whether this is currently the platform's default route.
  bool get isDefault;

  /// Whether the route is currently available for selection.
  bool get isAvailable;
}
