import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/event/player_event_type.dart' show PlayerEventType;

part 'player_event_type_filter.g.dart';

/// Immutable event type matcher.
///
/// This value object is useful when a consumer needs to describe a set of
/// accepted event categories without depending on a concrete event class.
abstract class PlayerEventTypeFilter implements Built<PlayerEventTypeFilter, PlayerEventTypeFilterBuilder> {
  /// Builds PlayerEventTypeFilter from a [updates] callback — the codegen entry.
  factory PlayerEventTypeFilter([void Function(PlayerEventTypeFilterBuilder)? updates]) = _$PlayerEventTypeFilter;

  /// Creates a matcher accepting the listed [types], or every category when
  /// [acceptAll] is set.
  factory PlayerEventTypeFilter.of({Set<PlayerEventType> types = const <PlayerEventType>{}, bool acceptAll = false}) {
    return PlayerEventTypeFilter(
      (builder) => builder
        ..types = types
        ..acceptAll = acceptAll,
    );
  }

  PlayerEventTypeFilter._();

  /// A matcher nobody filled in accepts nothing yet rather than everything:
  /// [acceptAll] is the explicit way to widen it.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PlayerEventTypeFilterBuilder builder) => builder
    ..types = const <PlayerEventType>{}
    ..acceptAll = false;

  /// Event categories considered relevant.
  Set<PlayerEventType> get types;

  /// Whether every category passes regardless of [types].
  bool get acceptAll;

  /// Whether [type] is accepted by this matcher.
  bool accepts(PlayerEventType type) {
    return acceptAll || types.contains(type);
  }
}
