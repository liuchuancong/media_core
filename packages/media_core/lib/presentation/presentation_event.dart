import 'presentation_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_event.freezed.dart';

/// Represents presentation lifecycle events.
///
/// Events describe something that happened or something
/// that should be processed by the presentation subsystem.
///
/// Events do not execute platform operations.
///
/// They are consumed by:
///
/// - PresentationController
/// - platform adapters
/// - state reducers
@freezed
abstract class PresentationEvent with _$PresentationEvent {
  const factory PresentationEvent({
    /// Event type.
    required PresentationEventType type,

    /// Related presentation mode.
    PresentationMode? mode,

    /// Lifecycle generation.
    ///
    /// Used to discard stale asynchronous callbacks.
    @Default(0) int generation,

    /// Optional event source.
    String? source,

    /// Optional error message.
    String? error,
  }) = _PresentationEvent;

  const PresentationEvent._();

  /// Request enter a presentation mode.
  factory PresentationEvent.requested(PresentationMode mode, {int generation = 0, String? source}) {
    return PresentationEvent(type: PresentationEventType.requested, mode: mode, generation: generation, source: source);
  }

  /// Platform transition started.
  factory PresentationEvent.started(PresentationMode mode, {int generation = 0, String? source}) {
    return PresentationEvent(type: PresentationEventType.started, mode: mode, generation: generation, source: source);
  }

  /// Platform transition completed.
  factory PresentationEvent.completed(PresentationMode mode, {int generation = 0, String? source}) {
    return PresentationEvent(type: PresentationEventType.completed, mode: mode, generation: generation, source: source);
  }

  /// Platform transition failed.
  factory PresentationEvent.failed(PresentationMode mode, {required String error, int generation = 0, String? source}) {
    return PresentationEvent(
      type: PresentationEventType.failed,
      mode: mode,
      error: error,
      generation: generation,
      source: source,
    );
  }

  /// Platform reported external change.
  factory PresentationEvent.updated(PresentationMode mode, {int generation = 0, String? source}) {
    return PresentationEvent(type: PresentationEventType.updated, mode: mode, generation: generation, source: source);
  }

  /// Presentation disposed.
  factory PresentationEvent.disposed({int generation = 0}) {
    return PresentationEvent(type: PresentationEventType.disposed, generation: generation);
  }

  /// Whether event contains an error.
  bool get hasError => error != null;
}

/// Presentation event categories.
enum PresentationEventType {
  /// User or system requested a transition.
  requested,

  /// Transition started.
  started,

  /// Transition completed.
  completed,

  /// Transition failed.
  failed,

  /// External state update.
  updated,

  /// Presentation subsystem disposed.
  disposed,
}
