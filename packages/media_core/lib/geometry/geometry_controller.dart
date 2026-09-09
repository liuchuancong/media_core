import 'dart:async';
import 'video_size.dart';
import 'display_size.dart';
import 'geometry_event.dart';
import 'geometry_state.dart';
import 'video_geometry.dart';
import 'video_rotation.dart';
import 'geometry_snapshot.dart';
import 'package:rxdart/rxdart.dart';


/// Controls video geometry lifecycle.
///
/// Responsibilities:
///
/// - own geometry state
/// - receive geometry events
/// - reduce state changes
/// - provide immutable snapshots
/// - protect against stale async updates
///
/// Does not:
///
/// - perform layout
/// - resize widgets
/// - control renderer
/// - call platform APIs
final class GeometryController {
  GeometryController({GeometryState initialState = const GeometryState.initial()})
    : _stateSubject = BehaviorSubject<GeometryState>.seeded(initialState);

  final BehaviorSubject<GeometryState> _stateSubject;

  bool _disposed = false;

  int _generation = 0;

  /// Current state stream.
  ValueStream<GeometryState> get state => _stateSubject.stream;

  /// Current state.
  GeometryState get current => _stateSubject.value;

  /// Current snapshot.
  GeometrySnapshot get snapshot => GeometrySnapshot.fromState(current);

  /// Current geometry.
  VideoGeometry get geometry => current.geometry;

  /// Current generation.
  int get generation => _generation;

  /// Whether geometry initialized.
  bool get initialized => current.initialized;

  /// Updates geometry.
  ///
  /// Called by:
  ///
  /// - player adapter
  /// - renderer backend
  /// - media metadata parser
  void update(VideoGeometry geometry) {
    _ensureNotDisposed();

    final generation = ++_generation;

    dispatch(GeometryEvent.changed(geometry, generation));
  }

  /// Updates video size.
  void updateVideoSize(VideoSize size) {
    _ensureNotDisposed();

    final next = current.geometry.copyWithVideoSize(size);

    update(next);
  }

  /// Updates display size.
  void updateDisplaySize(DisplaySize size) {
    _ensureNotDisposed();

    final next = current.geometry.copyWithDisplaySize(size);

    update(next);
  }

  /// Updates rotation.
  void updateRotation(VideoRotationInfo rotation) {
    _ensureNotDisposed();

    final next = current.geometry.copyWithRotation(rotation);

    update(next);
  }

  /// Clears geometry.
  void clear() {
    _ensureNotDisposed();

    final generation = ++_generation;

    dispatch(GeometryEvent.reset(generation));
  }

  /// Receives geometry event.
  void dispatch(GeometryEvent event) {
    _ensureNotDisposed();

    final next = current.reduce(event);

    if (next != current) {
      _stateSubject.add(next);
    }
  }

  /// Restores state.
  void restore(GeometryState state) {
    _ensureNotDisposed();

    if (state.generation < _generation) {
      return;
    }

    _generation = state.generation;

    _stateSubject.add(state);
  }

  /// Creates new generation.
  int nextGeneration() {
    return ++_generation;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('GeometryController has already been disposed.');
    }
  }

  /// Releases resources.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _stateSubject.close();
  }
}
