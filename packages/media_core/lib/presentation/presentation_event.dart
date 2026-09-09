import 'presentation_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'presentation_event.freezed.dart';

/// Represents presentation lifecycle events.
///
/// Events describe changes or requests
/// inside presentation subsystem.
///
/// Events do not:
///
/// - execute platform APIs
/// - modify state directly
///
/// They are consumed by:
///
/// - PresentationController
/// - PresentationReducer
/// - Platform adapters
@freezed
abstract class PresentationEvent with _$PresentationEvent {
  const factory PresentationEvent({
    /// Event category.
    required PresentationEventType type,

    /// Related presentation mode.
    PresentationMode? mode,

    /// Lifecycle generation.
    ///
    /// Used to ignore stale async callbacks.
    @Default(0) int generation,

    /// Event source.
    ///
    /// Examples:
    ///
    /// user
    /// android
    /// ios
    /// windows
    /// lifecycle
    String? source,

    /// Error message.
    String? error,
  }) = _PresentationEvent;

  const PresentationEvent._();

  /// Request presentation change.
  factory PresentationEvent.requested(PresentationMode mode, {int generation = 0, String? source}) {
    return PresentationEvent(type: PresentationEventType.requested, mode: mode, generation: generation, source: source);
  }

  /// Transition started.
  factory PresentationEvent.started(PresentationMode mode, {int generation = 0, String? source}) {
    return PresentationEvent(type: PresentationEventType.started, mode: mode, generation: generation, source: source);
  }

  /// Transition completed.
  factory PresentationEvent.completed(PresentationMode mode, {int generation = 0, String? source}) {
    return PresentationEvent(type: PresentationEventType.completed, mode: mode, generation: generation, source: source);
  }

  /// Transition failed.
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

  bool get hasError => error != null;

  bool get hasMode => mode != null;
}

/// Presentation event categories.
enum PresentationEventType {
  /// User/system requested transition.
  requested,

  /// Transition started.
  started,

  /// Transition completed.
  completed,

  /// Transition failed.
  failed,

  /// External platform update.
  updated,

  /// Presentation disposed.
  disposed,
}
