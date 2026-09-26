import 'dart:async';

import 'package:flutter/services.dart';

import 'desktop_lyric_state.dart';

/// An action the user performed on the desktop lyric overlay itself.
///
/// The overlay is a separate window, so its buttons do not reach the app's
/// widget tree — they come back over the transport as these actions.
enum DesktopLyricAction {
  /// Previous track.
  previous,

  /// Play/pause toggle.
  toggle,

  /// Next track.
  next,

  /// Close/hide the overlay.
  close,

  /// Lock the overlay (make it click-through).
  lock,

  /// Unlock the overlay.
  unlock,
}

/// Moves [DesktopLyricState] to whatever draws the overlay.
///
/// The split is deliberate:
///
/// - the Dart layer owns the *logic* — which line, which translation, how far
///   through, locked or not, styled how — and pushes whole states;
/// - the *window* is a platform object drawn outside the Flutter tree (a Win32
///   layered window, an Android `TYPE_APPLICATION_OVERLAY` window);
/// - [MethodChannelDesktopLyricTransport] is the protocol between the two.
///
/// The implementations shipping with this package:
///
/// | platform | window | notes |
/// |---|---|---|
/// | Windows | `windows/`, layered window drawn with GDI+ on its own thread | hover controls, dragging, click-through locking |
/// | Android | `android/`, `TYPE_APPLICATION_OVERLAY` added with the application context | needs `SYSTEM_ALERT_WINDOW`: the first [show] opens the system settings screen and returns false, so the host calls it again afterwards; survives leaving the player page, no Service of its own |
/// | macOS | `macos/`, borderless `NSWindow` at `.floating` level | joins every Space, never takes focus; `ignoresMouseEvents` makes the lock truly click-through |
/// | Linux | `linux/`, override-redirect GTK popup drawn with Cairo/Pango | click-through uses an empty input shape, which is X11-only: under Wayland a locked overlay hides its controls but still catches input |
/// | iOS, web | — | no cross-application overlay exists: iOS' equivalent is the lock screen / a Live Activity, and a web page cannot draw outside its own tab. [isSupported] stays false, which is not an error |
///
/// Every implementation speaks the vocabulary below; a platform without one
/// reports [isSupported] == false and the host simply does not offer the
/// feature.
abstract interface class DesktopLyricTransport {
  /// Whether the current platform/host can draw an overlay.
  Future<bool> isSupported();

  /// Shows the overlay, requesting whatever permission the platform needs.
  Future<bool> show();

  /// Hides the overlay.
  Future<void> hide();

  /// Pushes a full state.
  Future<void> update(DesktopLyricState state);

  /// Actions coming back from the overlay's own buttons.
  Stream<DesktopLyricAction> get actions;

  /// Releases transport resources.
  Future<void> dispose();
}

/// [DesktopLyricTransport] over a `MethodChannel` to the host app.
///
/// Protocol — channel `media_core_audio/desktop_lyric`:
///
/// | direction | method | arguments | result |
/// |---|---|---|---|
/// | Dart → host | `isSupported` | – | `bool` |
/// | Dart → host | `show` | – | `bool` (permission granted + window shown) |
/// | Dart → host | `hide` | – | – |
/// | Dart → host | `update` | [DesktopLyricState.toMap] | – |
/// | Dart → host | `setBounds` | `{x, y, width, height}` | – |
/// | host → Dart | `action` | `{action: <DesktopLyricAction.name>}` | – |
///
/// A host that never registers the channel is not an error: every call
/// degrades to "unsupported", and the controller stays usable.
final class MethodChannelDesktopLyricTransport implements DesktopLyricTransport {
  /// Creates a transport.
  MethodChannelDesktopLyricTransport({MethodChannel? channel, this.channelName = defaultChannelName})
    : _channel = channel ?? const MethodChannel(defaultChannelName);

  /// Default channel name.
  static const String defaultChannelName = 'media_core_audio/desktop_lyric';

  /// Channel this transport talks on.
  final String channelName;

  final MethodChannel _channel;
  final StreamController<DesktopLyricAction> _actions = StreamController<DesktopLyricAction>.broadcast();

  bool _handlerInstalled = false;
  bool? _supported;

  @override
  Stream<DesktopLyricAction> get actions => _actions.stream;

  @override
  Future<bool> isSupported() async {
    final cached = _supported;

    if (cached != null) {
      return cached;
    }

    try {
      final supported = await _channel.invokeMethod<bool>('isSupported') ?? false;

      _supported = supported;

      if (supported) {
        _installHandler();
      }

      return supported;
    } on MissingPluginException {
      // No host implementation on this platform: not an error, just "no
      // desktop lyrics here".
      _supported = false;

      return false;
    } on PlatformException {
      _supported = false;

      return false;
    }
  }

  @override
  Future<bool> show() async {
    if (!await isSupported()) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('show') ?? false;
    } on PlatformException {
      // Most commonly a denied overlay permission.
      return false;
    }
  }

  @override
  Future<void> hide() async {
    if (_supported != true) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('hide');
    } on PlatformException {
      // Hiding a window that is already gone is not worth reporting.
    }
  }

  @override
  Future<void> update(DesktopLyricState state) async {
    if (_supported != true) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('update', state.toMap());
    } on PlatformException {
      // A dropped frame of lyric text is invisible to the user; the next
      // update carries the full state anyway.
    }
  }

  /// Moves/resizes the overlay window.
  Future<void> setBounds({required double x, required double y, required double width, required double height}) async {
    if (_supported != true) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('setBounds', <String, Object?>{
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      });
    } on PlatformException {
      // Ignored: bounds are cosmetic.
    }
  }

  void _installHandler() {
    if (_handlerInstalled) {
      return;
    }

    _handlerInstalled = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'action') {
        return null;
      }

      final name = (call.arguments as Map?)?['action']?.toString();
      final action = DesktopLyricAction.values.where((value) => value.name == name).firstOrNull;

      if (action != null && !_actions.isClosed) {
        _actions.add(action);
      }

      return null;
    });
  }

  @override
  Future<void> dispose() async {
    if (_handlerInstalled) {
      _channel.setMethodCallHandler(null);
      _handlerInstalled = false;
    }

    await _actions.close();
  }
}

/// A transport that does nothing, for platforms or hosts without an overlay.
///
/// Using it keeps the controller code path identical everywhere: nothing needs
/// to know whether desktop lyrics exist on this device.
final class NoopDesktopLyricTransport implements DesktopLyricTransport {
  /// Creates the transport.
  NoopDesktopLyricTransport();

  @override
  Stream<DesktopLyricAction> get actions => const Stream<DesktopLyricAction>.empty();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> show() async => false;

  @override
  Future<void> hide() async {}

  @override
  Future<void> update(DesktopLyricState state) async {}

  @override
  Future<void> dispose() async {}
}
