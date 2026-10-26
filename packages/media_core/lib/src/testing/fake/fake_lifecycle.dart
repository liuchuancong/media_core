import 'package:clock/clock.dart';

import 'package:media_core/src/lifecycle/lifecycle_observer.dart';
import 'package:media_core/src/models/lifecycle/library.dart';

/// Recording [LifecycleObserver] for tests.
///
/// Stores every received event and offers helpers to build
/// lifecycle event sequences.
final class FakeLifecycleObserver implements LifecycleObserver {
  final List<LifecycleEvent> _events = <LifecycleEvent>[];

  /// Whether the observer was attached.
  bool attached = false;

  /// Whether the observer was detached.
  bool detached = false;

  /// Received events in order.
  List<LifecycleEvent> get events => List.unmodifiable(_events);

  /// Received event types in order.
  List<LifecycleEventType> get types => _events.map((event) => event.type).toList(growable: false);

  /// Number of received events.
  int get count => _events.length;

  /// Latest received event.
  LifecycleEvent? get last => _events.isEmpty ? null : _events.last;

  @override
  void onLifecycleEvent(LifecycleEvent event) {
    _events.add(event);
  }

  /// Whether an event type was received.
  bool received(LifecycleEventType type) {
    return _events.any((event) => event.type == type);
  }

  /// Marks the observer as attached.
  void markAttached() => attached = true;

  /// Marks the observer as detached.
  void markDetached() => detached = true;

  /// Clears recorded events.
  void reset() => _events.clear();
}

/// Builds [LifecycleEvent] values for tests.
final class FakeLifecycleEvents {
  const FakeLifecycleEvents._();

  /// Builds an event of [type] stamped with the current `clock.now`.
  static LifecycleEvent of(LifecycleEventType type, {DateTime? timestamp}) {
    return LifecycleEvent.of(type: type, timestamp: timestamp ?? clock.now());
  }

  /// A typical foreground sequence.
  static List<LifecycleEvent> foregroundSequence() {
    final now = clock.now();
    return [
      LifecycleEvent.of(type: LifecycleEventType.created, timestamp: now),
      LifecycleEvent.of(type: LifecycleEventType.initialized, timestamp: now),
      LifecycleEvent.of(type: LifecycleEventType.activated, timestamp: now),
    ];
  }

  /// A typical background sequence.
  static List<LifecycleEvent> backgroundSequence() {
    final now = clock.now();
    return [
      LifecycleEvent.of(type: LifecycleEventType.paused, timestamp: now),
      LifecycleEvent.of(type: LifecycleEventType.inactive, timestamp: now),
    ];
  }

  /// A full teardown sequence.
  static List<LifecycleEvent> disposeSequence() {
    final now = clock.now();
    return [
      LifecycleEvent.of(type: LifecycleEventType.inactive, timestamp: now),
      LifecycleEvent.of(type: LifecycleEventType.detached, timestamp: now),
      LifecycleEvent.of(type: LifecycleEventType.disposing, timestamp: now),
      LifecycleEvent.of(type: LifecycleEventType.disposed, timestamp: now),
    ];
  }
}
