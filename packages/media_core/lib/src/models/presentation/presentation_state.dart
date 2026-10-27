import 'package:built_value/built_value.dart';
import 'package:media_core/src/geometry/value/video_orientation.dart';
import 'package:media_core/src/presentation/descriptor/presentation_capabilities.dart';
import 'package:media_core/src/presentation/descriptor/presentation_mode.dart';
import 'package:media_core/src/presentation/driver/presentation_adapter.dart' show PresentationAdapter;

part 'presentation_state.g.dart';

/// Represents the current presentation lifecycle state.
///
/// This state is the logical source of truth for the
/// presentation subsystem.
///
/// It describes:
///
/// - current presentation mode
/// - target presentation mode
/// - transition status
/// - presentation capabilities
/// - presentation availability
/// - presentation errors
/// - lifecycle generation
///
/// It does not:
///
/// - enter fullscreen
/// - leave fullscreen
/// - create a PiP window
/// - create a floating window
/// - call platform APIs
/// - control system UI
///
/// Platform-specific operations are handled by
/// [PresentationAdapter].
abstract class PresentationState implements Built<PresentationState, PresentationStateBuilder> {
  /// Builds PresentationState from a [updates] callback — the codegen entry.
  factory PresentationState([void Function(PresentationStateBuilder)? updates]) = _$PresentationState;

  /// Creates a presentation state from its fields.
  factory PresentationState.of({
    PresentationMode mode = PresentationMode.normal,
    PresentationMode? targetMode,
    PresentationCapabilities capabilities = const PresentationCapabilities(),
    VideoOrientation orientation = VideoOrientation.unknown,
    bool transitioning = false,
    bool enabled = true,
    bool available = true,
    int generation = 0,
    String? error,
  }) {
    return PresentationState(
      (builder) => builder
        ..mode = mode
        ..targetMode = targetMode
        ..capabilities = capabilities
        ..orientation = orientation
        ..transitioning = transitioning
        ..enabled = enabled
        ..available = available
        ..generation = generation
        ..error = error,
    );
  }

  /// Creates the initial presentation state.
  ///
  /// The player starts in normal presentation mode.
  factory PresentationState.initial() {
    return PresentationState.of();
  }

  PresentationState._();

  /// The subsystem starts in normal mode with nothing pending: capabilities
  /// unprobed, orientation unknown, enabled, available, at generation zero.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(PresentationStateBuilder builder) => builder
    ..mode = PresentationMode.normal
    ..capabilities = const PresentationCapabilities()
    ..orientation = VideoOrientation.unknown
    ..transitioning = false
    ..enabled = true
    ..available = true
    ..generation = 0;

  /// Current active presentation mode.
  ///
  /// This represents the mode that has successfully
  /// completed.
  ///
  /// During a transition, this value remains unchanged
  /// until the transition is completed.
  PresentationMode get mode;

  /// Target presentation mode.
  ///
  /// This is non-null while a transition is being
  /// processed.
  ///
  /// Example:
  ///
  /// ```text
  /// mode:
  ///   normal
  ///
  /// targetMode:
  ///   fullscreen
  ///
  /// transitioning:
  ///   true
  /// ```
  PresentationMode? get targetMode;

  /// Presentation capabilities reported by the
  /// current environment.
  ///
  /// Capabilities describe what the environment supports.
  /// They do not describe the current presentation mode.
  PresentationCapabilities get capabilities;

  /// Orientation of the media currently being presented.
  ///
  /// Both fullscreen variants present differently per orientation — a
  /// portrait video filling a portrait phone, a landscape video taking over
  /// the screen, a portrait video letterboxed on a desktop monitor — so the
  /// orientation belongs to the presentation state rather than to one
  /// platform's driver. Drivers and hosts read it to pick a layout strategy;
  /// nothing here decides that strategy for them.
  VideoOrientation get orientation;

  /// Whether a presentation transition is currently
  /// running.
  bool get transitioning;

  /// Whether the presentation subsystem is enabled.
  ///
  /// This represents application-level availability of
  /// presentation functionality.
  bool get enabled;

  /// Whether presentation is currently available.
  ///
  /// This can become false when the presentation subsystem
  /// cannot currently perform presentation operations.
  ///
  /// Examples:
  ///
  /// - player has been disposed
  /// - required platform resource is unavailable
  /// - presentation lifecycle has ended
  bool get available;

  /// Lifecycle generation.
  ///
  /// Used to distinguish newer presentation operations
  /// from stale asynchronous callbacks.
  ///
  /// The controller owns generation changes.
  ///
  /// The reducer uses generation to prevent an older
  /// asynchronous event from overwriting newer state.
  int get generation;

  /// Last presentation error.
  ///
  /// A null value means that the current state does not
  /// contain a presentation error.
  String? get error;

  /// Whether fullscreen presentation is active.
  bool get isFullscreen => mode == PresentationMode.fullscreen;

  /// Whether picture-in-picture presentation is active.
  bool get isPip => mode == PresentationMode.pip;

  /// Whether floating presentation is active.
  bool get isFloating => mode == PresentationMode.floating;

  /// Whether normal presentation is active.
  bool get isNormal => mode == PresentationMode.normal;

  /// Whether a presentation transition is running.
  bool get isTransitioning => transitioning;

  /// Whether the state contains a presentation error.
  bool get hasError => error != null;

  /// Whether a target presentation mode exists.
  bool get hasTarget => targetMode != null;

  /// Whether the current presentation mode is supported
  /// by the current environment.
  bool get isSupported => capabilities.supports(mode);

  /// Whether a new presentation request can currently
  /// be accepted.
  ///
  /// A request cannot be accepted when:
  ///
  /// - presentation is disabled
  /// - presentation is unavailable
  /// - another transition is running
  /// - the current state contains an error
  bool get canRequestChange => enabled && available && !transitioning && !hasError;

  /// A copy with the given fields replaced; an omitted field keeps its current
  /// value. That is freezed's reading, kept because callers rely on it — the
  /// places that meant to *clear* `error` or `targetMode` now say so with an
  /// explicit `rebuild`, instead of passing a null this method could not tell
  /// apart from an omission.
  PresentationState copyWith({
    PresentationMode? mode,
    PresentationMode? targetMode,
    PresentationCapabilities? capabilities,
    VideoOrientation? orientation,
    bool? transitioning,
    bool? enabled,
    bool? available,
    int? generation,
    String? error,
  }) {
    return rebuild((builder) => builder
      ..mode = mode ?? builder.mode
      ..targetMode = targetMode ?? builder.targetMode
      ..capabilities = capabilities ?? builder.capabilities
      ..orientation = orientation ?? builder.orientation
      ..transitioning = transitioning ?? builder.transitioning
      ..enabled = enabled ?? builder.enabled
      ..available = available ?? builder.available
      ..generation = generation ?? builder.generation
      ..error = error ?? builder.error);
  }

  /// Creates a state representing a pending transition.
  ///
  /// The current [mode] is intentionally preserved.
  ///
  /// Only [targetMode] and transition status change, and the error the last
  /// attempt left behind is dropped: a new attempt starts clean.
  PresentationState transitioningTo(PresentationMode target) {
    return rebuild(
      (builder) => builder
        ..targetMode = target
        ..transitioning = true
        ..error = null,
    );
  }

  /// Creates a state representing a successfully
  /// completed transition.
  ///
  /// The new mode becomes the current active mode and
  /// the pending target is cleared.
  PresentationState completed(PresentationMode newMode) {
    return rebuild(
      (builder) => builder
        ..mode = newMode
        ..targetMode = null
        ..transitioning = false
        ..error = null,
    );
  }

  /// Creates a state representing a failed transition.
  ///
  /// The current active mode is preserved because the
  /// requested transition did not complete successfully, and the pending
  /// target is cleared with it.
  PresentationState failed(String message) {
    return rebuild(
      (builder) => builder
        ..targetMode = null
        ..transitioning = false
        ..error = message,
    );
  }
}
