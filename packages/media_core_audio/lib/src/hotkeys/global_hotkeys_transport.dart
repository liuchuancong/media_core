import 'dart:async';

import 'package:flutter/services.dart';

/// A system-wide shortcut the user pressed outside the app.
///
/// The OS registration lives in the host; when a registered combination fires
/// — no matter which application has focus — the host reports it back as one
/// of these. [combo] is the registered combination string, [action] whatever
/// name the caller attached to it: both are the caller's own vocabulary,
/// passed through untouched.
final class GlobalHotkeyEvent {
  /// Creates an event.
  const GlobalHotkeyEvent({required this.combo, required this.action});

  /// The combination string as it was registered, e.g. `mod+alt+f5`.
  final String combo;

  /// The action name the caller registered for [combo].
  final String action;
}

/// Registers system-wide shortcuts with the operating system.
///
/// A global shortcut fires even when the app has no focus, which is what
/// separates it from an in-app accelerator: the OS routes the key here before
/// the focused application ever sees it. Registration is a limited resource —
/// a combination another application already holds cannot be taken — so
/// [replace] answers per combination instead of one blanket success.
///
/// The values on this interface belong to the caller: combination strings in
/// whatever notation the host uses (the reference's `mod+alt+f5` reads well
/// and round-trips through a config file), action names as opaque strings.
///
/// The implementations shipping with this package:
///
/// | platform | registration | notes |
/// |---|---|---|
/// | Windows | `RegisterHotKey` on a message-only window the plugin owns | `WM_HOTKEY` hops back through the plugin's action window |
/// | Linux, macOS | — | not implemented yet; [isSupported] stays false, which is not an error |
abstract interface class GlobalHotkeysTransport {
  /// Whether the current platform/host can register global shortcuts.
  Future<bool> isSupported();

  /// Atomically replaces the whole registered table.
  ///
  /// Every combination from the previous table is released first, then each
  /// entry of [combos] — combination string to action name — is registered.
  /// The answer maps each combination to whether the OS accepted it; a `false`
  /// entry usually means another application already holds the combination.
  Future<Map<String, bool>> replace(Map<String, String> combos);

  /// Releases every registered combination.
  Future<void> clear();

  /// Combinations the user pressed, wherever the focus was.
  Stream<GlobalHotkeyEvent> get events;

  /// Releases transport resources; also unregisters everything.
  Future<void> dispose();
}

/// [GlobalHotkeysTransport] over a `MethodChannel` to the host app.
///
/// Protocol — channel `media_core_audio/global_hotkeys`:
///
/// | direction | method | arguments | result |
/// |---|---|---|---|
/// | Dart → host | `isSupported` | – | `bool` |
/// | Dart → host | `replace` | `{combos: {combo: action}}` | `{combo: bool}` |
/// | Dart → host | `clear` | – | – |
/// | host → Dart | `fired` | `{combo, action}` | – |
///
/// A host that never registers the channel is not an error: every call
/// degrades to "unsupported", and the caller simply does not offer the
/// feature.
final class MethodChannelGlobalHotkeysTransport implements GlobalHotkeysTransport {
  /// Creates a transport.
  MethodChannelGlobalHotkeysTransport({MethodChannel? channel, this.channelName = defaultChannelName})
    : _channel = channel ?? const MethodChannel(defaultChannelName);

  /// Default channel name.
  static const String defaultChannelName = 'media_core_audio/global_hotkeys';

  /// Channel this transport talks on.
  final String channelName;

  final MethodChannel _channel;
  final StreamController<GlobalHotkeyEvent> _events = StreamController<GlobalHotkeyEvent>.broadcast();

  bool _handlerInstalled = false;
  bool? _supported;

  @override
  Stream<GlobalHotkeyEvent> get events => _events.stream;

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
      // global shortcuts here".
      _supported = false;

      return false;
    } on PlatformException {
      _supported = false;

      return false;
    }
  }

  @override
  Future<Map<String, bool>> replace(Map<String, String> combos) async {
    if (!await isSupported()) {
      return const {};
    }

    try {
      final answer = await _channel.invokeMethod<Map<Object?, Object?>>('replace', <String, Object?>{
        'combos': combos,
      });

      return {
        for (final entry in (answer ?? const {}).entries) '${entry.key}': entry.value == true,
      };
    } on PlatformException {
      // A host that fails the whole table answers with nothing registered.
      return {for (final combo in combos.keys) combo: false};
    }
  }

  @override
  Future<void> clear() async {
    if (_supported != true) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('clear');
    } on PlatformException {
      // Nothing left registered either way.
    }
  }

  void _installHandler() {
    if (_handlerInstalled) {
      return;
    }

    _handlerInstalled = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'fired') {
        return null;
      }

      final arguments = call.arguments as Map?;
      final combo = arguments?['combo']?.toString();
      final action = arguments?['action']?.toString();

      if (combo != null && action != null && !_events.isClosed) {
        _events.add(GlobalHotkeyEvent(combo: combo, action: action));
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

    await clear();
    await _events.close();
  }
}

/// A transport that does nothing, for platforms or hosts without global
/// shortcuts.
///
/// Using it keeps the caller code path identical everywhere: nothing needs to
/// know whether global shortcuts exist on this device.
final class NoopGlobalHotkeysTransport implements GlobalHotkeysTransport {
  /// Creates the transport.
  NoopGlobalHotkeysTransport();

  @override
  Stream<GlobalHotkeyEvent> get events => const Stream<GlobalHotkeyEvent>.empty();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<Map<String, bool>> replace(Map<String, String> combos) async => const {};

  @override
  Future<void> clear() async {}

  @override
  Future<void> dispose() async {}
}
