import 'presentation_event.dart';
import 'presentation_state.dart';

/// Reduces presentation events into presentation states.
///
/// This class is a pure state transformer.
///
/// Responsibilities:
///
/// - convert events into states
/// - handle transition lifecycle
/// - synchronize generation
/// - manage targetMode
///
/// Does not:
///
/// - call platform APIs
/// - perform async operations
/// - dispatch requests
final class PresentationReducer {
  const PresentationReducer();

  /// Applies event and returns next state.
  PresentationState reduce(PresentationState state, PresentationEvent event) {
    //
    // Ignore stale callbacks.
    //
    if (event.generation < state.generation) {
      return state;
    }

    final int generation = event.generation > state.generation ? event.generation : state.generation;

    switch (event.type) {
      //
      // Request created.
      //
      case PresentationEventType.requested:
        return state.copyWith(targetMode: event.mode, transitioning: true, generation: generation, error: null);

      //
      // Platform transition started.
      //
      case PresentationEventType.started:
        return state.copyWith(targetMode: event.mode, transitioning: true, generation: generation, error: null);

      //
      // Platform transition completed.
      //
      case PresentationEventType.completed:
        return state.copyWith(
          mode: event.mode ?? state.mode,
          targetMode: null,
          transitioning: false,
          generation: generation,
          error: null,
        );

      //
      // Platform transition failed.
      //
      case PresentationEventType.failed:
        return state.copyWith(
          targetMode: null,
          transitioning: false,
          generation: generation,
          error: event.error ?? 'Unknown presentation error',
        );

      //
      // External platform state update.
      //
      case PresentationEventType.updated:
        return state.copyWith(
          mode: event.mode ?? state.mode,
          targetMode: null,
          transitioning: false,
          generation: generation,
          error: null,
        );

      //
      // Controller disposed.
      //
      case PresentationEventType.disposed:
        return state.copyWith(targetMode: null, transitioning: false, generation: generation);
    }
  }
}
