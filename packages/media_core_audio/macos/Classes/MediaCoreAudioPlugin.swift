import Carbon.HIToolbox
import Cocoa
import FlutterMacOS

/// macOS side of `media_core_audio`'s desktop-lyric overlay.
///
/// Wire protocol (see `MethodChannelDesktopLyricTransport` on the Dart side,
/// which is the source of truth):
///
/// | direction | method | arguments | result |
/// |---|---|---|---|
/// | Dart → host | `isSupported` | – | true |
/// | Dart → host | `show` | – | window shown |
/// | Dart → host | `hide` | – | – |
/// | Dart → host | `update` | state map | – |
/// | Dart → host | `setBounds` | {x, y, width, height} | – |
/// | host → Dart | `action` | {action: previous/toggle/next/close/lock/unlock} | – |
///
/// The window lives on the main thread, which is also where Flutter's macOS
/// embedder delivers channel calls, so actions can be sent straight back
/// without a marshalling layer.
public class MediaCoreAudioPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?
  private var hotkeyChannel: FlutterMethodChannel?
  private var window: DesktopLyricWindow?

  // Global shortcuts (Carbon `RegisterEventHotKey`): the registration table,
  // keyed by the id handed to Carbon; the shared event handler reads the id
  // off the event and looks the combination up here.
  private var hotkeys: [UInt32: (combo: String, action: String, ref: EventHotKeyRef?)] = [:]
  private var nextHotkeyId: UInt32 = 1
  private var hotkeyHandlerInstalled = false

  /// The instance whose table the shared Carbon event handler reports into —
  /// Carbon installs one handler per process, so it needs process-wide access.
  private static weak var hotkeyInstance: MediaCoreAudioPlugin?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "media_core_audio/desktop_lyric",
      binaryMessenger: registrar.messenger
    )

    let instance = MediaCoreAudioPlugin()
    instance.channel = channel

    registrar.addMethodCallDelegate(instance, channel: channel)

    let hotkeyChannel = FlutterMethodChannel(
      name: "media_core_audio/global_hotkeys",
      binaryMessenger: registrar.messenger
    )

    instance.hotkeyChannel = hotkeyChannel

    registrar.addMethodCallDelegate(
      GlobalHotkeysDelegate(owner: instance), channel: hotkeyChannel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(ensureWindow().isSupported)

    case "show":
      result(ensureWindow().show())

    case "hide":
      window?.hide()
      result(nil)

    case "update":
      if let arguments = call.arguments as? [String: Any] {
        ensureWindow().update(parse(arguments))
      }
      result(nil)

    case "setBounds":
      if let arguments = call.arguments as? [String: Any] {
        ensureWindow().setBounds(
          x: number(arguments["x"]) ?? 0,
          y: number(arguments["y"]) ?? 0,
          width: number(arguments["width"]) ?? 900,
          height: number(arguments["height"]) ?? 150
        )
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  deinit {
    clearHotkeys()
    window?.dispose()
  }

  // MARK: - Internals

  private func ensureWindow() -> DesktopLyricWindow {
    if let existing = window {
      return existing
    }

    let created = DesktopLyricWindow { [weak self] action in
      guard let self = self, let channel = self.channel else { return }
      channel.invokeMethod("action", arguments: ["action": action])
    }

    window = created

    return created
  }

  private func parse(_ map: [String: Any]) -> LyricWindowState {
    var state = LyricWindowState()

    state.text = string(map["text"]) ?? "♪"
    state.translation = string(map["translation"]) ?? ""
    state.nextLine = string(map["nextLine"]) ?? ""
    state.progress = number(map["progress"]) ?? 0
    state.playing = (map["playing"] as? Bool) ?? false
    state.locked = (map["locked"] as? Bool) ?? false
    state.hasLyrics = (map["hasLyrics"] as? Bool) ?? true

    if let style = map["style"] as? [String: Any] {
      if let family = string(style["fontFamily"]), !family.isEmpty {
        state.fontFamily = family
      }

      state.fontSize = number(style["fontSize"]) ?? state.fontSize
      state.strokeWidth = number(style["strokeWidth"]) ?? state.strokeWidth
      state.opacity = number(style["opacity"]) ?? state.opacity
      state.alignment = string(style["alignment"]) ?? state.alignment
      state.lineGap = number(style["lineGap"]) ?? state.lineGap
      state.boldLine = (style["boldLine"] as? Bool) ?? state.boldLine
      state.boldExtended = (style["boldExtended"] as? Bool) ?? state.boldExtended

      // The Dart side sends colours as 0xAARRGGBB ints, the same encoding the
      // native windows take: no Flutter types cross the channel.
      if let text = style["textColor"] as? NSNumber {
        state.textColor = Self.color(text.uint32Value)
      }
      if let stroke = style["strokeColor"] as? NSNumber {
        state.strokeColor = Self.color(stroke.uint32Value)
      }
    }

    return state
  }

  private func string(_ value: Any?) -> String? {
    value as? String
  }

  private func number(_ value: Any?) -> CGFloat? {
    if let double = value as? Double { return CGFloat(double) }
    if let int = value as? Int { return CGFloat(int) }

    return nil
  }

  private static func color(_ argb: UInt32) -> NSColor {
    let alpha = CGFloat((argb >> 24) & 0xFF) / 255
    let red = CGFloat((argb >> 16) & 0xFF) / 255
    let green = CGFloat((argb >> 8) & 0xFF) / 255
    let blue = CGFloat(argb & 0xFF) / 255

    return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
  }
}

/// The `media_core_audio/global_hotkeys` channel's delegate. It rides its own
/// channel so its method names never collide with the lyric overlay's.
final class GlobalHotkeysDelegate: NSObject, FlutterPlugin {
  private weak var owner: MediaCoreAudioPlugin?

  init(owner: MediaCoreAudioPlugin) {
    self.owner = owner
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    // Routed through MediaCoreAudioPlugin.register, which installs this
    // delegate itself; the Flutter tooling never calls this directly.
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    owner?.handleHotkeyMethod(call, result: result)
  }
}

extension MediaCoreAudioPlugin {
  /// Wire protocol — channel `media_core_audio/global_hotkeys`:
  ///
  /// | direction | method | arguments | result |
  /// |---|---|---|---|
  /// | Dart → host | `isSupported` | – | `bool` |
  /// | Dart → host | `replace` | `{combos: {combo: action}}` | `{combo: bool}` |
  /// | Dart → host | `clear` | – | – |
  /// | host → Dart | `fired` | `{combo, action}` | – |
  ///
  /// `mod+alt+f5` notation, the same vocabulary the Windows host parses;
  /// `mod` reads as Ctrl, matching the Windows table rather than the usual
  /// macOS command key.
  func handleHotkeyMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)

    case "replace":
      guard let arguments = call.arguments as? [String: Any],
            let combos = arguments["combos"] as? [String: String] else {
        result([String: Bool]())

        return
      }

      result(replaceHotkeys(combos))

    case "clear":
      clearHotkeys()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func replaceHotkeys(_ combos: [String: String]) -> [String: Bool] {
    clearHotkeys()

    if !hotkeyHandlerInstalled {
      var eventType = EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard),
        eventKind: UInt32(kEventHotKeyPressed))

      InstallEventHandler(
        GetApplicationEventTarget(), Self.hotkeyEventHandler, 1, &eventType,
        nil, nil)

      hotkeyHandlerInstalled = true
      Self.hotkeyInstance = self
    }

    var answer: [String: Bool] = [:]

    for (combo, action) in combos {
      guard let parsed = parse(combo) else {
        answer[combo] = false

        continue
      }

      let id = nextHotkeyId
      nextHotkeyId += 1

      let hotKeyID = EventHotKeyID(
        signature: OSType(0x484C_544B) /* 'HLTK' */, id: id)
      var ref: EventHotKeyRef?

      let status = RegisterEventHotKey(
        parsed.keyCode, parsed.modifiers, hotKeyID,
        GetApplicationEventTarget(), 0, &ref)

      if status == noErr {
        hotkeys[id] = (combo, action, ref)
      }

      answer[combo] = status == noErr
    }

    return answer
  }

  private func clearHotkeys() {
    for entry in hotkeys.values {
      if let ref = entry.ref {
        UnregisterEventHotKey(ref)
      }
    }

    hotkeys.removeAll()
  }

  private func fireHotkey(id: UInt32) {
    guard let entry = hotkeys[id], let hotkeyChannel = hotkeyChannel else {
      return
    }

    hotkeyChannel.invokeMethod("fired", arguments: ["combo": entry.combo, "action": entry.action])
  }

  private static let hotkeyEventHandler: EventHandlerUPP = { _, event, _ in
    guard let event = event else { return noErr }

    var hotKeyID = EventHotKeyID()

    let status = GetEventParameter(
      event, EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID), nil,
      MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

    guard status == noErr else { return noErr }

    hotkeyInstance?.fireHotkey(id: hotKeyID.id)

    return noErr
  }

  private func parse(_ combo: String) -> (keyCode: UInt32, modifiers: UInt32)? {
    var modifiers: UInt32 = 0
    var key: String?

    for part in combo.split(separator: "+") {
      switch part {
      case "mod", "ctrl":
        modifiers |= UInt32(controlKeyMask)
      case "alt":
        modifiers |= UInt32(optionKeyMask)
      case "shift":
        modifiers |= UInt32(shiftKeyMask)
      default:
        if key == nil {
          key = String(part)
        } else {
          return nil
        }
      }
    }

    guard let key = key, let keyCode = Self.keyCode(of: key) else {
      return nil
    }

    return (keyCode, modifiers)
  }

  /// The non-modifier key's virtual key code, in the caller's lower-case
  /// vocabulary — the same names the Windows host parses. Unknown names fail,
  /// which surfaces as a failed registration rather than a stuck key.
  private static let punctuationKeyCodes: [String: Int] = [
    "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal, ",": kVK_ANSI_Comma,
    ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash, ";": kVK_ANSI_Semicolon,
    "'": kVK_ANSI_Quote, "[": kVK_ANSI_LeftBracket,
    "]": kVK_ANSI_RightBracket, "\\": kVK_ANSI_Backslash,
    "`": kVK_ANSI_Grave,
  ]

  private static let namedKeyCodes: [String: Int] = [
    "arrowleft": kVK_LeftArrow, "arrowright": kVK_RightArrow,
    "arrowup": kVK_UpArrow, "arrowdown": kVK_DownArrow,
    "space": kVK_Space, "enter": kVK_Return, "escape": kVK_Escape,
    "tab": kVK_Tab, "backspace": kVK_Delete, "delete": kVK_ForwardDelete,
    "insert": kVK_Help, "home": kVK_Home, "end": kVK_End,
    "pageup": kVK_PageUp, "pagedown": kVK_PageDown,
  ]

  /// Carbon's F-key constants are not contiguous, so they get a real table.
  private static let functionKeyCodes: [Int: Int] = [
    1: kVK_F1, 2: kVK_F2, 3: kVK_F3, 4: kVK_F4, 5: kVK_F5, 6: kVK_F6,
    7: kVK_F7, 8: kVK_F8, 9: kVK_F9, 10: kVK_F10, 11: kVK_F11,
    12: kVK_F12, 13: kVK_F13, 14: kVK_F14, 15: kVK_F15, 16: kVK_F16,
    17: kVK_F17, 18: kVK_F18, 19: kVK_F19, 20: kVK_F20,
  ]

  private static func keyCode(of key: String) -> UInt32? {
    if key.count == 1 {
      let character = Character(key)

      if let scalar = character.unicodeScalars.first, scalar.value >= 97,
         scalar.value <= 122 {
        // kVK_ANSI_A through kVK_ANSI_Z are contiguous.
        return UInt32(kVK_ANSI_A + (scalar.value - 97))
      }

      return punctuationKeyCodes[key].map { UInt32($0) }
    }

    if let found = namedKeyCodes[key] {
      return UInt32(found)
    }

    if key.count >= 2, key.hasPrefix("f"), let number = Int(key.dropFirst()),
       number >= 1, number <= 20 {
      return functionKeyCodes[number].map { UInt32($0) }
    }

    return nil
  }
}
