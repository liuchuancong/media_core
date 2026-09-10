import 'dart:async';
import 'lifecycle_event.dart';
import 'lifecycle_state.dart';
import 'player_lifecycle.dart';
import 'lifecycle_observer.dart';
import 'lifecycle_snapshot.dart';
import 'package:clock/clock.dart';
import 'package:rxdart/rxdart.dart';


/// Controls player lifecycle.
final class LifecycleController implements PlayerLifecycle {
  LifecycleController();

  LifecycleState _state = const LifecycleState();

  final BehaviorSubject<LifecycleSnapshot> _snapshotSubject = BehaviorSubject.seeded(LifecycleSnapshot.initial());

  final PublishSubject<LifecycleEvent> _eventSubject = PublishSubject();

  final List<LifecycleObserver> _observers = [];

  @override
  LifecycleSnapshot get snapshot {
    return _snapshotSubject.value;
  }

  @override
  Stream<LifecycleEvent> get events {
    return _eventSubject.stream;
  }

  Stream<LifecycleSnapshot> get snapshots {
    return _snapshotSubject.stream;
  }

  void addObserver(LifecycleObserver observer) {
    _observers.add(observer);
  }

  void removeObserver(LifecycleObserver observer) {
    _observers.remove(observer);
  }

  @override
  void create() {
    _update(_state.markCreated(), LifecycleEventType.created);
  }

  @override
  void initialize() {
    _update(_state.markInitialized(), LifecycleEventType.initialized);
  }

  @override
  void activate() {
    _update(_state.markActive(), LifecycleEventType.activated);
  }

  @override
  void pause() {
    _update(_state.markPaused(), LifecycleEventType.paused);
  }

  @override
  void resume() {
    _update(_state.markActive(), LifecycleEventType.resumed);
  }

  @override
  void deactivate() {
    _update(_state.markInactive(), LifecycleEventType.inactive);
  }

  @override
  void detach() {
    _update(_state.markDetached(), LifecycleEventType.detached);
  }

  @override
  void dispose() {
    _update(_state.markDisposing(), LifecycleEventType.disposing);

    _update(_state.markDisposed(), LifecycleEventType.disposed);

    _snapshotSubject.close();
    _eventSubject.close();
  }

  void _update(LifecycleState state, LifecycleEventType type) {
    _state = state;

    final event = LifecycleEvent.now(type);

    final snapshot = LifecycleSnapshot(state: state, updatedAt: clock.now());

    _snapshotSubject.add(snapshot);

    _eventSubject.add(event);

    for (final observer in List.of(_observers)) {
      observer.onLifecycleEvent(event);
    }
  }
}
