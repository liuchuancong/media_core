import 'dart:async';
import 'event_filter.dart';
import 'player_event.dart';

/// Represents one active event subscription.
///
/// A subscription owns only delivery configuration. The event bus remains
/// responsible for event transport.
final class EventSubscription {
  EventSubscription({required StreamSubscription<PlayerEvent> subscription, EventFilter? filter, this.once = false})
    : _subscription = subscription,
      filter = filter ?? const AllowAllEventFilter();

  final StreamSubscription<PlayerEvent> _subscription;

  final EventFilter filter;

  final bool once;

  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void pause([Future<void>? resumeSignal]) {
    _subscription.pause(resumeSignal);
  }

  void resume() {
    _subscription.resume();
  }

  Future<void> cancel() async {
    if (_cancelled) {
      return;
    }

    _cancelled = true;
    await _subscription.cancel();
  }
}
