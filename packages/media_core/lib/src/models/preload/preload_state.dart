import 'package:built_value/built_value.dart';

part 'preload_state.g.dart';

/// Runtime preload state.
abstract class PreloadState implements Built<PreloadState, PreloadStateBuilder> {
  /// Builds a state from a [updates] callback — the codegen entry.
  factory PreloadState([void Function(PreloadStateBuilder)? updates]) = _$PreloadState;

  /// Creates a preload state from its individual phase flags.
  factory PreloadState.of({
    bool pending = false,
    bool loading = false,
    bool completed = false,
    bool failed = false,
    bool cancelled = false,
  }) {
    return PreloadState(
      (builder) => builder
        ..pending = pending
        ..loading = loading
        ..completed = completed
        ..failed = failed
        ..cancelled = cancelled,
    );
  }

  PreloadState._();

  /// A task nobody has queued yet is in no phase at all.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PreloadStateBuilder builder) => builder
    ..pending = false
    ..loading = false
    ..completed = false
    ..failed = false
    ..cancelled = false;

  /// Whether the task is queued and waiting to load.
  bool get pending;

  /// Whether the source is currently loading.
  bool get loading;

  /// Whether the preload finished successfully.
  bool get completed;

  /// Whether the preload failed.
  bool get failed;

  /// Whether the preload was cancelled.
  bool get cancelled;

  /// Whether no preload phase is active.
  bool get isIdle => !pending && !loading && !completed && !failed && !cancelled;

  /// Whether the source is actively loading.
  bool get isRunning => loading;

  /// Whether the preload reached a terminal state.
  bool get isFinished => completed || failed || cancelled;

  /// Returns the queued state.
  PreloadState queued() {
    return PreloadState.of(pending: true);
  }

  /// Returns the loading state.
  PreloadState start() {
    return PreloadState.of(loading: true);
  }

  /// Returns the successfully completed state.
  PreloadState complete() {
    return PreloadState.of(completed: true);
  }

  /// Returns the failed state.
  PreloadState fail() {
    return PreloadState.of(failed: true);
  }

  /// Returns the cancelled state.
  PreloadState cancel() {
    return PreloadState.of(cancelled: true);
  }
}
