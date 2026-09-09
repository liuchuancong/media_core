import 'visibility_event.dart';

/// Receives visibility changes.
abstract interface class VisibilityObserver {
  void onVisibilityEvent(VisibilityEvent event);
}
