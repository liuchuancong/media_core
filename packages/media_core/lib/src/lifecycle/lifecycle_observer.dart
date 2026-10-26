import 'package:media_core/src/models/lifecycle/library.dart';

/// Receives lifecycle events.
abstract interface class LifecycleObserver {
  /// Called for each player lifecycle transition until the observer is removed.
  void onLifecycleEvent(LifecycleEvent event);
}
