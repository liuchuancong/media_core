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
  private var window: DesktopLyricWindow?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "media_core_audio/desktop_lyric",
      binaryMessenger: registrar.messenger
    )

    let instance = MediaCoreAudioPlugin()
    instance.channel = channel

    registrar.addMethodCallDelegate(instance, channel: channel)
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
