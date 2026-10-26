import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/visibility/visibility_state.dart';

part 'visibility_snapshot.g.dart';

/// Immutable visibility snapshot.
abstract class VisibilitySnapshot implements Built<VisibilitySnapshot, VisibilitySnapshotBuilder> {
  /// Builds a snapshot from a [updates] callback — the codegen entry.
  factory VisibilitySnapshot([void Function(VisibilitySnapshotBuilder)? updates]) = _$VisibilitySnapshot;

  /// Creates a snapshot from explicit values.
  factory VisibilitySnapshot.of({required VisibilityState state, DateTime? updatedAt}) {
    return VisibilitySnapshot(
      (builder) => builder
        ..state = state.toBuilder()
        ..updatedAt = updatedAt,
    );
  }

  VisibilitySnapshot._();

  /// Snapshot of the default hidden state.
  factory VisibilitySnapshot.initial() {
    return VisibilitySnapshot.of(state: VisibilityState.of());
  }

  /// Visibility state captured with this snapshot.
  VisibilityState get state;

  /// When the snapshot was taken; null for hand-built snapshots.
  DateTime? get updatedAt;

  /// Whether the player was visible when the snapshot was taken.
  bool get visible => state.visible;

  /// Share of the player that was on screen, from 0.0 to 1.0.
  double get ratio => state.visibility;
}
