import 'package:built_value/built_value.dart';
import 'package:media_core/src/identity/generation_id.dart';

part 'session_generation.g.dart';

/// Represents a playback generation inside a session.
///
/// A session can contain multiple generations when:
///
/// - source changes
/// - player recreates
/// - retry happens
/// - fallback switches backend
///
/// Older generations must not affect newer ones.
abstract class SessionGeneration
    implements Built<SessionGeneration, SessionGenerationBuilder>, Comparable<SessionGeneration> {
  /// Builds a generation from a [updates] callback — the codegen entry.
  factory SessionGeneration([void Function(SessionGenerationBuilder)? updates]) = _$SessionGeneration;

  /// Creates a session generation.
  factory SessionGeneration.of({required GenerationId id, required int number}) {
    return SessionGeneration(
      (builder) => builder
        ..id = id
        ..number = number,
    );
  }

  SessionGeneration._();

  /// Creates the first generation.
  factory SessionGeneration.initial() {
    return SessionGeneration.of(id: GenerationId.generate(), number: 0);
  }

  /// Generation identity.
  GenerationId get id;

  /// Increasing generation number.
  int get number;

  /// Whether this is the initial generation.
  bool get isInitial {
    return number == 0;
  }

  /// Creates the next generation.
  SessionGeneration next() {
    return SessionGeneration.of(id: GenerationId.generate(), number: number + 1);
  }

  /// Whether another generation is newer.
  bool isNewerThan(SessionGeneration other) {
    return number > other.number;
  }

  /// Whether another generation is older.
  bool isOlderThan(SessionGeneration other) {
    return number < other.number;
  }

  /// Checks generation equality.
  bool isSameAs(SessionGeneration other) {
    return this == other;
  }

  /// Compares generations.
  @override
  int compareTo(SessionGeneration other) {
    return number.compareTo(other.number);
  }
}
