import 'dart:async';

import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:window_manager/window_manager.dart';

import 'package:media_core_pip/src/pip_window.dart';

/// One monitor's usable area, id'd for remembered-bounds matching.
final class PipWorkArea {
  const PipWorkArea({required this.id, required this.area});

  final String id;

  final Rect area;
}

/// Host-supplied display enumeration for multi-monitor placement.
typedef PipWorkAreasReader = Future<List<PipWorkArea>> Function();

/// Remembered small-window geometry; null when the host stores none or the
/// feature is off.
final class PipSavedBounds {
  const PipSavedBounds({required this.displayId, required this.bounds});

  final String displayId;

  final Rect bounds;
}

typedef PipSavedBoundsReader = PipSavedBounds? Function();

typedef PipSavedBoundsWriter = void Function(Size size, Offset position, String displayId);

/// Sizing policy for the small window, by content aspect ratio.
///
/// Landscape caps the long side at 360, portrait at 380 with a 140 floor,
/// and near-square at 280 — small enough to float over content, large
/// enough to stay legible.
Size pipSmallWindowSize(double aspectRatio) {
  final ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 16 / 9;
  if (ratio > 1.05) {
    const maxSide = 360.0;
    return Size(maxSide, maxSide / ratio);
  }
  if (ratio < 0.95) {
    const maxSide = 380.0;
    var width = maxSide * ratio;
    if (width < 140) {
      width = 140;
    }
    return Size(width, width / ratio);
  }
  const maxSide = 280.0;
  return ratio >= 1.0 ? Size(maxSide, maxSide / ratio) : Size(maxSide * ratio, maxSide);
}

String? pipDisplayIdForPosition(List<PipWorkArea> displays, Offset position) {
  for (final display in displays) {
    final area = display.area;
    if (position.dx >= area.left && position.dx < area.right && position.dy >= area.top && position.dy < area.bottom) {
      return display.id;
    }
  }
  for (final display in displays) {
    final area = display.area;
    if (position.dx < area.right && position.dx + 1 > area.left && position.dy < area.bottom && position.dy + 1 > area.top) {
      return display.id;
    }
  }
  return null;
}

/// Places the small window inside the monitor family.
///
/// A remembered placement wins when at least 48×48 of it still overlaps one
/// monitor; otherwise the monitor holding the primary work area hosts the
/// window. The size is clamped to the target area (140×90 floor) and the
/// position to its bounds, defaulting to the bottom-right corner with a
/// [placementMargin] gap.
Rect pipResolvePlacement({
  required Size requestedSize,
  required List<Rect> workAreas,
  required Rect primaryWorkArea,
  Rect? savedBounds,
  double placementMargin = 20,
}) {
  final areas = workAreas.where((area) => !area.isEmpty && area.isFinite).toList(growable: false);
  final fallbackArea = primaryWorkArea.isEmpty ? const Rect.fromLTWH(0, 0, 1280, 720) : primaryWorkArea;
  final candidates = areas.isEmpty ? <Rect>[fallbackArea] : areas;
  final validSaved = savedBounds != null && savedBounds.isFinite && !savedBounds.isEmpty ? savedBounds : null;

  Rect target;
  if (validSaved != null) {
    target = candidates.firstWhere(
      (area) {
        final overlap = validSaved.intersect(area);
        return overlap.width >= 48 && overlap.height >= 48;
      },
      orElse: () => Rect.zero,
    );
  } else {
    target = Rect.zero;
  }
  if (target == Rect.zero) {
    target = candidates.firstWhere(
      (area) => area.overlaps(fallbackArea) || area.contains(fallbackArea.center),
      orElse: () => candidates.first,
    );
  }

  final requested = validSaved?.size ?? requestedSize;
  final minWidth = target.width < 140 ? target.width : 140.0;
  final minHeight = target.height < 90 ? target.height : 90.0;
  final width = requested.width.clamp(minWidth, target.width).toDouble();
  final height = requested.height.clamp(minHeight, target.height).toDouble();
  final defaultLeft = target.right - width - placementMargin;
  final defaultTop = target.bottom - height - placementMargin;
  final left = (validSaved?.left ?? defaultLeft).clamp(target.left, target.right - width).toDouble();
  final top = (validSaved?.top ?? defaultTop).clamp(target.top, target.bottom - height).toDouble();
  return Rect.fromLTWH(left, top, width, height);
}

/// Desktop small window with the full placement policy: multi-monitor
/// awareness, remembered bounds with display matching, minimum-size
/// release, host rollback on failure and a serialized operation queue.
///
/// Display enumeration is injected so hosts with their own screen plugin
/// stay dependency-free; single-display hosts can omit the reader and the
/// current window's monitor bounds stand in for the work area.
final class DisplayAwarePipWindow implements PipWindow {
  DisplayAwarePipWindow({
    this.workAreasReader,
    this.readSavedBounds,
    this.writeSavedBounds,
    bool Function()? alwaysOnTop,
    this.normalMinSize = Size.zero,
    this.defaultSize = const Size(1280, 720),
    this.placementMargin = 20,
  }) : _alwaysOnTop = alwaysOnTop;

  final PipWorkAreasReader? workAreasReader;
  final PipSavedBoundsReader? readSavedBounds;
  final PipSavedBoundsWriter? writeSavedBounds;
  final bool Function()? _alwaysOnTop;
  final Size normalMinSize;
  final Size defaultSize;
  final double placementMargin;

  final List<Future<void>> _opQueue = [];
  Size _savedSize = const Size(1280, 720);
  Offset _savedPosition = Offset.zero;
  bool _compact = false;
  bool get isCompact => _compact;

  Future<void> setAlwaysOnTop(bool value) {
    return _serialize(() async {
      if (!_compact) return;
      await windowManager.setAlwaysOnTop(value);
    });
  }

  /// Persists the current small-window geometry when remembered bounds are on.
  Future<void> captureGeometry() {
    return _serialize(() async {
      if (!_compact) return;
      final saved = readSavedBounds?.call();
      if (saved == null) return;
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      final displays = await _workAreas();
      final displayId =
          pipDisplayIdForPosition(displays, position) ??
          (displays.isEmpty ? null : _displayOfCurrentView(displays));
      if (displayId == null) return;
      writeSavedBounds?.call(size, position, displayId);
    });
  }

  @override
  Future<PipWindowSnapshot> capture() async {
    final position = await windowManager.getPosition();
    final bounds = await windowManager.getBounds();
    return PipWindowSnapshot(
      bounds: Rect.fromLTWH(position.dx, position.dy, bounds.width, bounds.height),
      alwaysOnTop: await windowManager.isAlwaysOnTop(),
      resizable: await windowManager.isResizable(),
      skipTaskbar: await windowManager.isSkipTaskbar(),
      title: await windowManager.getTitle(),
    );
  }

  @override
  Future<void> applySmallWindow({
    required Size size,
    required Offset position,
    required double? aspectRatio,
    required bool alwaysOnTop,
    required bool resizable,
    required bool skipTaskbar,
    required String title,
  }) {
    return _serialize(() => _enter(aspectRatio ?? size.width / size.height, alwaysOnTop));
  }

  @override
  Future<void> restore(PipWindowSnapshot snapshot) {
    return _serialize(_exit);
  }

  Future<void> _enter(double aspectRatio, bool alwaysOnTopOverride) async {
    if (_compact) return;
    final normalSize = await windowManager.getSize();
    final normalPosition = await windowManager.getPosition();
    final normalAlwaysOnTop = await windowManager.isAlwaysOnTop();

    final displays = await _workAreas();
    final currentId = pipDisplayIdForPosition(displays, normalPosition);
    PipWorkArea current = displays.firstWhere(
      (display) => display.id == currentId,
      orElse: () => displays.isEmpty ? PipWorkArea(id: '', area: _currentViewWorkArea()) : displays.first,
    );

    final saved = readSavedBounds?.call();
    final savedMatches = saved != null && (saved.displayId.isEmpty || saved.displayId == current.id);
    final placement = pipResolvePlacement(
      requestedSize: pipSmallWindowSize(aspectRatio),
      workAreas: [for (final display in displays) display.area],
      primaryWorkArea: current.area,
      savedBounds: savedMatches ? saved.bounds : null,
      placementMargin: placementMargin,
    );

    final pinOnTop = _alwaysOnTop?.call() ?? alwaysOnTopOverride;
    try {
      await windowManager.setAlwaysOnTop(pinOnTop);
      await windowManager.setMinimumSize(Size.zero);
      await windowManager.setSize(placement.size);
      await windowManager.setPosition(placement.topLeft);
      final landedId = pipDisplayIdForPosition(displays, placement.topLeft) ?? current.id;
      writeSavedBounds?.call(placement.size, placement.topLeft, landedId);
    } catch (error, stackTrace) {
      await _rollback(
        minimumSize: normalMinSize,
        size: normalSize,
        position: normalPosition,
        alwaysOnTop: normalAlwaysOnTop,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }

    _savedSize = normalSize;
    _savedPosition = normalPosition;
    _compact = true;
  }

  Future<void> _exit() async {
    if (!_compact) return;
    final pipSize = await windowManager.getSize();
    final pipPosition = await windowManager.getPosition();
    final pipAlwaysOnTop = await windowManager.isAlwaysOnTop();
    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(normalMinSize);
      await windowManager.setSize(_savedSize);
      await windowManager.setPosition(_savedPosition);
    } catch (error, stackTrace) {
      await _rollback(minimumSize: Size.zero, size: pipSize, position: pipPosition, alwaysOnTop: pipAlwaysOnTop);
      Error.throwWithStackTrace(error, stackTrace);
    }
    _compact = false;
  }

  Future<void> _rollback({
    required Size minimumSize,
    required Size size,
    required Offset position,
    required bool alwaysOnTop,
  }) async {
    final steps = <Future<void> Function()>[
      () => windowManager.setMinimumSize(minimumSize),
      () => windowManager.setSize(size),
      () => windowManager.setPosition(position),
      () => windowManager.setAlwaysOnTop(alwaysOnTop),
    ];
    for (final step in steps) {
      try {
        await step();
      } catch (_) {}
    }
  }

  Future<List<PipWorkArea>> _workAreas() async {
    final reader = workAreasReader;
    if (reader != null) {
      final areas = await reader();
      if (areas.isNotEmpty) return areas;
    }
    return [PipWorkArea(id: '', area: _currentViewWorkArea())];
  }

  Rect _currentViewWorkArea() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return const Rect.fromLTWH(0, 0, 1280, 720);
    final view = views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    return Rect.fromLTWH(0, 0, size.width, size.height);
  }

  String _displayOfCurrentView(List<PipWorkArea> displays) => displays.first.id;

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _opQueue.isEmpty ? operation() : _opQueue.last.then((_) => operation());
    _opQueue.add(result);
    unawaited(
      result.whenComplete(() {
        _opQueue.remove(result);
      }).catchError((_) {}),
    );
    return result;
  }
}
