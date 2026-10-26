import 'package:media_core/src/models/presentation/library.dart';
import 'package:media_core/src/presentation/state/presentation_event.dart';

/// Reduces presentation events into presentation states.
///
/// PresentationReducer is a pure state transformer.
///
/// Responsibilities:
///
/// - convert events into states
/// - handle presentation lifecycle
/// - synchronize generation
/// - clear transition state
/// - handle errors
///
/// Does not:
///
/// - call platform APIs
/// - perform async operations
/// - dispatch requests
/// - manage lifecycle
///
/// Flow:
///
/// PresentationEvent
///        │
///        ▼
/// PresentationReducer
///        │
///        ▼
/// PresentationState
///
final class PresentationReducer {
  /// Creates the stateless reducer.
  const PresentationReducer();

  /// Applies an event and returns next state.
  PresentationState reduce(PresentationState state, PresentationEvent event) {
    //
    // Ignore stale async callbacks.
    //
    if (event.generation < state.generation) {
      return state;
    }

    final generation = event.generation > state.generation ? event.generation : state.generation;

    return switch (event) {
      //
      // Transition started.
      //
      final PresentationStarted event => state.copyWith(
        targetMode: event.mode,
        transitioning: true,
        generation: generation,
        // Deliberately redundant: copyWith keeps the current value when an
        // argument is omitted, which is what this did under freezed.
        // ignore: avoid_redundant_argument_values
        error: null,
      ),

      //
      // Transition completed.
      //
      final PresentationCompleted event => state.copyWith(
        mode: event.mode,
        // Deliberately redundant: copyWith keeps the current value when an
        // argument is omitted, which is what this did under freezed.
        // ignore: avoid_redundant_argument_values
        targetMode: null,
        transitioning: false,
        generation: generation,
        // Deliberately redundant: copyWith keeps the current value when an
        // argument is omitted, which is what this did under freezed.
        // ignore: avoid_redundant_argument_values
        error: null,
      ),

      //
      // Transition failed.
      //
      final PresentationFailed event => state.copyWith(
        // Deliberately redundant: copyWith keeps the current value when an
        // argument is omitted, which is what this did under freezed.
        // ignore: avoid_redundant_argument_values
        targetMode: null,
        transitioning: false,
        generation: generation,
        error: event.error,
      ),

      //
      // Platform changed state externally.
      //
      final PresentationChanged event => state.copyWith(
        mode: event.mode,
        // Deliberately redundant: copyWith keeps the current value when an
        // argument is omitted, which is what this did under freezed.
        // ignore: avoid_redundant_argument_values
        targetMode: null,
        transitioning: false,
        generation: generation,
        // Deliberately redundant: copyWith keeps the current value when an
        // argument is omitted, which is what this did under freezed.
        // ignore: avoid_redundant_argument_values
        error: null,
      ),

      //
      // Controller disposed.
      //
      // Deliberately redundant: copyWith keeps the current value when an
      // argument is omitted, which is what this did under freezed.
      // ignore: avoid_redundant_argument_values
      PresentationDisposed _ => state.copyWith(targetMode: null, transitioning: false, generation: generation),
    };
  }
}
