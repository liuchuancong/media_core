import 'dart:async';
import 'dart:collection';

import 'package:media_core_memory/media_core_memory.dart';

import 'danmaku_message.dart';
import 'danmaku_overlay_config.dart';

/// One message scheduled on a small surface.
final class DanmakuOverlayItem {
  const DanmakuOverlayItem({
    required this.message,
    required this.enqueuedAt,
    required this.lifetime,
    required this.fontSize,
    required this.opacity,
    required this.speedMultiplier,
    required this.displayAreaFraction,
  });

  final DanmakuMessage message;

  /// When the item entered the overlay. The host's renderer animates from here.
  final DateTime enqueuedAt;

  /// How long the item should stay on screen.
  ///
  /// Derived from the message's own style when it has one (a fixed-placement
  /// message carries its own duration), otherwise from the overlay's scaling
  /// rules: a scaled-down font covers the same distance faster, so the lifetime
  /// is stretched to keep the text readable.
  final Duration lifetime;

  /// Font size already scaled for the surface.
  final double fontSize;

  /// Opacity already combined with the overlay's own.
  final double opacity;

  /// Speed multiplier the renderer should apply.
  final double speedMultiplier;

  /// Fraction of the surface height available to danmaku.
  final double displayAreaFraction;

  /// Whether the item is still on screen at [now].
  bool isLiveAt(DateTime now) => now.difference(enqueuedAt) < lifetime;

  @override
  String toString() => 'DanmakuOverlayItem(${message.userName}: ${message.text})';
}

/// Danmaku on a small surface: its own queue, its own style, its own bound.
///
/// Responsibilities:
///
/// - hold the messages a small surface should draw, separately from the main
///   surface's queue
/// - drop what no longer fits instead of building a backlog
/// - empty itself when the surface goes away
/// - scale the presentation to the surface's size
///
/// It does not:
///
/// - decode or filter platform messages (the session does)
/// - draw anything (the host renders [items])
/// - decide when a small surface exists (the host owns the window; this binds
///   to its visibility stream)
///
/// ## Why the queue is separate
///
/// The main surface keeps a long queue on purpose: a viewer reading a busy room
/// wants a backlog. A small window does not — twelve messages is already more
/// than a 320-pixel window can show before they leave the screen, and a queue
/// that grows while the window is hidden replays stale chat when it returns.
/// Keeping the two apart is what lets both behave correctly.
///
/// ## Binding instead of depending
///
/// [bindVisibility] takes the visibility stream of whatever surface this
/// overlay belongs to — `PipDriver.onPipChanged`, `FloatingDriver.
/// onFloatingChanged`, or a host's own signal. The danmaku package therefore
/// knows nothing about picture-in-picture, floating windows or their platform
/// drivers, and those packages need no danmaku dependency to be usable.
final class DanmakuOverlaySession {
  DanmakuOverlaySession({DanmakuOverlayConfig config = DanmakuOverlayConfig.defaults}) : _config = config;

  DanmakuOverlayConfig _config;

  /// Insertion-ordered so the oldest message can be dropped in O(1).
  final LinkedHashMap<int, DanmakuOverlayItem> _items = LinkedHashMap<int, DanmakuOverlayItem>();

  /// Ledger of the queued messages.
  ///
  /// An overlay queue is small by design ([DanmakuOverlayConfig.maxMessages]),
  /// which is exactly why it is worth counting: a wall of cells each holding
  /// their own queue is where "small by design" stops being small.
  /// This instance's key in the shared account.
  late final String _memoryKey = memoryContributorKey(this);

  final MemoryAccount _memory = MediaCoreMemory.of(MemoryModule.danmaku);

  final StreamController<bool> _activeController = StreamController<bool>.broadcast();

  StreamSubscription<bool>? _visibilitySubscription;

  int _sequence = 0;
  bool _surfaceVisible = false;
  bool _disposed = false;

  /// Current configuration.
  DanmakuOverlayConfig get config => _config;

  /// Whether the overlay accepts messages right now.
  ///
  /// Requires both a visible surface and [DanmakuOverlayConfig.enabled]: a
  /// hidden window keeps nothing.
  bool get isActive => !_disposed && _surfaceVisible && _config.enabled;

  /// Whether the surface this overlay is bound to is currently visible.
  bool get isSurfaceVisible => _surfaceVisible;

  /// Active-state changes.
  Stream<bool> get onActiveChanged => _activeController.stream;

  /// Messages currently on the overlay, oldest first.
  List<DanmakuOverlayItem> get items => List<DanmakuOverlayItem>.unmodifiable(_items.values);

  /// Number of queued messages.
  int get length => _items.length;

  /// Follows [visibility] to know when the surface appears and disappears.
  ///
  /// The first event is treated as authoritative: a stream that starts with
  /// `true` means the surface is already up. Re-binding replaces the previous
  /// subscription so a surface swap cannot leave two feeds running.
  void bindVisibility(Stream<bool> visibility) {
    _ensureNotDisposed();
    _visibilitySubscription?.cancel();
    _visibilitySubscription = visibility.listen(_handleVisibility, onError: (_) {});
  }

  /// Stops following the bound surface.
  void unbindVisibility() {
    _visibilitySubscription?.cancel();
    _visibilitySubscription = null;
    _handleVisibility(false);
  }

  /// Applies a new configuration.
  ///
  /// Shrinking [DanmakuOverlayConfig.maxMessages] trims immediately, and
  /// disabling the overlay empties it: a disabled overlay that keeps messages
  /// would replay them the moment it is enabled again.
  void updateConfig(DanmakuOverlayConfig config) {
    _ensureNotDisposed();
    _config = config;
    if (!config.enabled) {
      clear();
      return;
    }
    _trim();
    _notifyActiveChanged();
  }

  /// Offers [message] to the overlay.
  ///
  /// Returns whether it was queued. A message is refused when the overlay is
  /// inactive (hidden or disabled) — the caller does not need to check first.
  ///
  /// [surfaceWidth] is what the font size is scaled against; pass the current
  /// window width when it is known.
  bool enqueue(DanmakuMessage message, {double? surfaceWidth, DateTime? now}) {
    _ensureNotDisposed();
    if (!isActive) {
      return false;
    }
    if (message.text.trim().isEmpty) {
      return false;
    }

    final at = now ?? DateTime.now();
    final item = _buildItem(message, surfaceWidth: surfaceWidth, at: at);

    // Evicting the oldest is deliberate: on a small surface the newest message
    // is the one the viewer can still act on, and a full queue means the
    // overlay is behind, not that the incoming message is unwanted.
    while (_items.length >= _config.maxMessages) {
      _items.remove(_items.keys.first);
    }

    _items[_sequence++] = item;
    _reportMemory();
    return true;
  }

  /// Removes items whose lifetime has passed, returning what was removed.
  ///
  /// The host's renderer calls this on its frame tick; nothing here is
  /// time-driven, so a paused app does not accumulate work.
  List<DanmakuOverlayItem> evictExpired({DateTime? now}) {
    _ensureNotDisposed();
    final at = now ?? DateTime.now();
    final expired = <DanmakuOverlayItem>[];
    _items.removeWhere((_, item) {
      if (item.isLiveAt(at)) {
        return false;
      }
      expired.add(item);
      return true;
    });
    if (expired.isNotEmpty) {
      _reportMemory();
    }
    return expired;
  }

  /// Empties the overlay.
  void clear() {
    _items.clear();
    _reportMemory(note: 'overlay cleared');
  }

  /// Reports the queued messages and their estimated cost.
  void _reportMemory({String? note}) {
    _memory.report(_memoryKey, 
      items: _items.length,
      bytes: _items.length * MemoryEstimates.danmakuMessage,
      note: note ?? '${_items.length}/${_config.maxMessages} queued',
    );
  }

  /// Font size for a surface of [surfaceWidth] logical pixels.
  ///
  /// Below the reference width the text shrinks, above it grows, bounded by
  /// [DanmakuOverlayConfig.minScale] and [DanmakuOverlayConfig.maxScale] so a
  /// tiny window stays legible and a maximised one does not turn into a banner.
  double fontSizeFor(double surfaceWidth) {
    final base = _config.fontSize;
    if (!_config.scaleWithSurface || surfaceWidth <= 0 || _config.referenceWidth <= 0) {
      return base;
    }
    final scale = (surfaceWidth / _config.referenceWidth).clamp(_config.minScale, _config.maxScale);
    return base * scale;
  }

  /// Display area for a surface of [surfaceHeight], in logical pixels.
  double displayAreaFor(double surfaceHeight) => surfaceHeight * _config.displayAreaFraction.clamp(0.1, 1.0);

  /// Releases the overlay.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    await _visibilitySubscription?.cancel();
    _visibilitySubscription = null;
    _disposed = true;
    clear();
    _memory.withdraw(_memoryKey);
    await _activeController.close();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _handleVisibility(bool visible) {
    if (visible == _surfaceVisible) {
      return;
    }
    _surfaceVisible = visible;
    if (!visible && _config.clearOnHide) {
      clear();
    }
    _notifyActiveChanged();
  }

  DanmakuOverlayItem _buildItem(DanmakuMessage message, {double? surfaceWidth, required DateTime at}) {
    final width = surfaceWidth ?? _config.referenceWidth;
    final fontSize = fontSizeFor(width);
    final style = message.style;

    // A scaled font covers the same fraction of the surface in less time, so
    // the lifetime is stretched by the inverse of the scale to keep the reading
    // window roughly constant.
    final scale = _config.fontSize <= 0 ? 1.0 : fontSize / _config.fontSize;
    final speed = _config.speedMultiplier.clamp(0.1, 10.0);
    final baseLifetime = Duration(milliseconds: (6000 / speed / (scale <= 0 ? 1 : scale)).round());
    final lifetime = style != null && style.placement != DanmakuPlacement.scroll
        ? Duration(milliseconds: style.fixedDurationMs)
        : baseLifetime;

    return DanmakuOverlayItem(
      message: message,
      enqueuedAt: at,
      lifetime: lifetime,
      fontSize: fontSize,
      opacity: (message.style?.opacity ?? 1) * _config.opacity.clamp(0.0, 1.0),
      speedMultiplier: speed,
      displayAreaFraction: _config.displayAreaFraction.clamp(0.1, 1.0),
    );
  }

  void _trim() {
    while (_items.length > _config.maxMessages) {
      _items.remove(_items.keys.first);
    }
  }

  void _notifyActiveChanged() {
    if (!_activeController.isClosed) {
      _activeController.add(isActive);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('DanmakuOverlaySession has been disposed.');
    }
  }
}
