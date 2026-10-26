import 'package:built_value/built_value.dart';

part 'lifecycle_state.g.dart';

/// Runtime lifecycle state.
abstract class LifecycleState implements Built<LifecycleState, LifecycleStateBuilder> {
  /// Builds a state from a [updates] callback — the codegen entry.
  factory LifecycleState([void Function(LifecycleStateBuilder)? updates]) = _$LifecycleState;

  /// Creates a state from its individual transition flags.
  factory LifecycleState.of({
    bool created = false,
    bool initialized = false,
    bool active = false,
    bool paused = false,
    bool inactive = false,
    bool detached = false,
    bool disposing = false,
    bool disposed = false,
  }) {
    return LifecycleState(
      (builder) => builder
        ..created = created
        ..initialized = initialized
        ..active = active
        ..paused = paused
        ..inactive = inactive
        ..detached = detached
        ..disposing = disposing
        ..disposed = disposed,
    );
  }

  LifecycleState._();

  /// A player that has not been constructed yet is in no phase at all.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LifecycleStateBuilder builder) => builder
    ..created = false
    ..initialized = false
    ..active = false
    ..paused = false
    ..inactive = false
    ..detached = false
    ..disposing = false
    ..disposed = false;

  /// Whether the player object has been constructed.
  bool get created;

  /// Whether the backend engine has been initialized.
  bool get initialized;

  /// Whether the player is bound to a foreground surface and able to play.
  bool get active;

  /// Whether playback is paused while the player remains active.
  bool get paused;

  /// Whether the player has been released from its surface (for example, backgrounded).
  bool get inactive;

  /// Whether the player has been detached from its resources ahead of disposal.
  bool get detached;

  /// Whether disposal has started but not finished.
  bool get disposing;

  /// Whether disposal has completed; a terminal, one-way flag.
  bool get disposed;

  /// Whether the player has not yet been disposed.
  bool get isAlive {
    return !disposed;
  }

  /// Whether the player is initialized and not tearing down.
  bool get isReady {
    return initialized && !disposing && !disposed;
  }

  /// Whether the player has reached the terminal disposed state.
  bool get isTerminal {
    return disposed;
  }

  /// Marks the player as constructed.
  LifecycleState markCreated() {
    return rebuild((builder) => builder..created = true);
  }

  /// Marks the backend engine as initialized.
  LifecycleState markInitialized() {
    return rebuild((builder) => builder..initialized = true);
  }

  /// Makes the player the active, foreground surface, clearing paused/inactive/detached.
  LifecycleState markActive() {
    return rebuild((builder) {
      builder
        ..active = true
        ..paused = false
        ..inactive = false
        ..detached = false;
    });
  }

  /// Records a pause that keeps the player active but stops playback.
  LifecycleState markPaused() {
    return rebuild((builder) {
      builder
        ..active = false
        ..paused = true
        ..inactive = false;
    });
  }

  /// Records release from the surface, clearing active and paused.
  LifecycleState markInactive() {
    return rebuild((builder) {
      builder
        ..active = false
        ..paused = false
        ..inactive = true;
    });
  }

  /// Marks the player detached from its resources, clearing the playing flags.
  LifecycleState markDetached() {
    return rebuild((builder) {
      builder
        ..detached = true
        ..active = false
        ..paused = false
        ..inactive = false;
    });
  }

  /// Marks disposal as started, clearing the playing flags.
  LifecycleState markDisposing() {
    return rebuild((builder) {
      builder
        ..disposing = true
        ..active = false
        ..paused = false
        ..inactive = false;
    });
  }

  /// Marks disposal complete and the state terminal, clearing every other flag.
  LifecycleState markDisposed() {
    return rebuild((builder) {
      builder
        ..disposing = false
        ..disposed = true
        ..active = false
        ..paused = false
        ..inactive = false;
    });
  }
}
