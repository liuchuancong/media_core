import Cocoa

/// Everything the overlay draws.
///
/// A whole state rather than deltas: the window redraws from this struct, so a
/// half-applied update can never be painted.
struct LyricWindowState {
  var text: String = "♪"
  var translation: String = ""
  var nextLine: String = ""
  var progress: Double = 0
  var playing: Bool = false
  var locked: Bool = false
  var hasLyrics: Bool = true

  var fontFamily: String?
  var fontSize: CGFloat = 40
  var textColor: NSColor = .white
  var strokeColor: NSColor = .black
  var strokeWidth: CGFloat = 2
  var opacity: CGFloat = 1
  var alignment: String = "center"
}

/// The desktop lyric overlay on macOS.
///
/// A borderless `NSWindow` at `.floating` level that joins every Space and
/// never becomes key or main, so it sits above the user's work without stealing
/// focus. `ignoresMouseEvents` is what makes the locked state really
/// click-through — macOS supports it per window, unlike Wayland.
///
/// Everything runs on the main thread (Cocoa requires it), which is also the
/// thread Flutter's macOS embedder delivers platform channel calls on — so no
/// message hop is needed here, unlike the Windows implementation.
final class DesktopLyricWindow {
  typealias ActionCallback = (String) -> Void

  private static let lockHintSeconds: TimeInterval = 2.0

  private let onAction: ActionCallback
  private var window: LyricWindow!
  private var contentView: LyricContentView!
  private var state = LyricWindowState()

  private var lockHintActive = false
  private var lockHintTimer: Timer?

  init(onAction: @escaping ActionCallback) {
    self.onAction = onAction
  }

  var isSupported: Bool { true }

  @discardableResult
  func show() -> Bool {
    ensureWindow()

    // `orderFrontRegardless` shows the panel without activating the app: the
    // overlay must never pull focus away from what the user is doing.
    window.orderFrontRegardless()
    contentView.needsDisplay = true

    return true
  }

  func hide() {
    window?.orderOut(nil)
  }

  func setBounds(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    ensureWindow()
    window.setFrame(
      NSRect(x: x, y: y, width: max(200, width), height: max(80, height)),
      display: true
    )
    contentView.needsDisplay = true
  }

  func update(_ next: LyricWindowState) {
    ensureWindow()

    let lockChanged = next.locked != state.locked
    state = next

    if lockChanged {
      if state.locked {
        // The hint keeps the panel interactive for a moment so the user sees
        // what happened before it stops accepting input.
        lockHintActive = true

        lockHintTimer?.invalidate()
        lockHintTimer = Timer.scheduledTimer(
          withTimeInterval: Self.lockHintSeconds,
          repeats: false
        ) { [weak self] _ in
          guard let self = self else { return }
          self.lockHintActive = false
          self.applyClickThrough()
          self.contentView.needsDisplay = true
        }
      } else {
        lockHintActive = false
        lockHintTimer?.invalidate()
        lockHintTimer = nil
      }
    }

    applyClickThrough()
    contentView.needsDisplay = true
  }

  func dispose() {
    lockHintTimer?.invalidate()
    lockHintTimer = nil
    window?.orderOut(nil)
    window = nil
    contentView = nil
  }

  // MARK: - Internals

  private func ensureWindow() {
    guard window == nil else { return }

    let frame = defaultFrame()
    let panel = LyricWindow(
      contentRect: frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    panel.isMovableByWindowBackground = false
    panel.hidesOnDeactivate = false

    contentView = LyricContentView(frame: NSRect(origin: .zero, size: frame.size))
    contentView.owner = self
    panel.contentView = contentView

    window = panel
  }

  private func defaultFrame() -> NSRect {
    let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let width = min(900, screen.width - 80)
    let height: CGFloat = 150
    let x = screen.minX + (screen.width - width) / 2
    // AppKit's origin is bottom-left: "a bit above the bottom edge" is a small
    // positive offset from minY.
    let y = screen.minY + screen.height * 0.12

    return NSRect(x: x, y: y, width: width, height: height)
  }

  private func applyClickThrough() {
    window?.ignoresMouseEvents = state.locked && !lockHintActive
  }

  fileprivate var currentState: LyricWindowState { state }

  fileprivate var isLockHintActive: Bool { lockHintActive }

  fileprivate var controlsVisible: Bool { !state.locked || lockHintActive }

  fileprivate func emit(_ action: String) {
    onAction(action)
  }
}

/// A borderless panel that must never take focus.
final class LyricWindow: NSWindow {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

/// Draws the overlay and translates clicks into actions.
///
/// Custom drawing rather than a stack of labels: the text needs an outline
/// (`.strokeWidth` on an attributed string gives stroke plus fill), and the
/// controls are geometric shapes, so one `draw(_:)` is both simpler and closer
/// to what the other platforms do.
final class LyricContentView: NSView {
  weak var owner: DesktopLyricWindow?

  private var hovering = false
  private var trackingArea: NSTrackingArea?
  private var pressedAction: String?
  private var dragging = false
  private var dragMouseOrigin: NSPoint = .zero
  private var dragWindowOrigin: NSPoint = .zero

  private var controlAreas: [(action: String, rect: NSRect)] = []

  override var isFlipped: Bool { true }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let existing = trackingArea {
      removeTrackingArea(existing)
    }

    let area = NSTrackingArea(
      rect: bounds,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )

    addTrackingArea(area)
    trackingArea = area
  }

  override func mouseEntered(with event: NSEvent) {
    hovering = true
    needsDisplay = true
  }

  override func mouseExited(with event: NSEvent) {
    hovering = false
    needsDisplay = true
  }

  // MARK: - Drawing

  override func draw(_ dirtyRect: NSRect) {
    guard let owner = owner,
          let context = NSGraphicsContext.current?.cgContext else { return }

    let state = owner.currentState
    let width = bounds.width
    let height = bounds.height

    // Panel.
    let panel = NSBezierPath(
      roundedRect: NSRect(x: 0, y: 0, width: width, height: height),
      xRadius: 14,
      yRadius: 14
    )
    NSColor.black.withAlphaComponent(0.6 * max(0, min(1, state.opacity))).setFill()
    panel.fill()

    layoutControls(width: width)
    let strip = owner.controlsVisible && (hovering || owner.isLockHintActive)
    let top: CGFloat = strip ? 34 : 8

    if strip {
      drawControls(state: state)
    }

    var cursor = top
    drawLine(
      state.text.isEmpty ? "♪" : state.text,
      y: cursor,
      size: state.fontSize,
      bold: true,
      color: state.textColor,
      state: state
    )
    cursor += state.fontSize * 1.3

    if state.hasLyrics && !state.translation.isEmpty {
      drawLine(
        state.translation,
        y: cursor,
        size: state.fontSize * 0.42,
        bold: false,
        color: NSColor.white.withAlphaComponent(0.8),
        state: state
      )
      cursor += state.fontSize * 0.55
    }

    if state.hasLyrics && !state.nextLine.isEmpty && height > 120 {
      drawLine(
        state.nextLine,
        y: cursor,
        size: state.fontSize * 0.34,
        bold: false,
        color: NSColor.white.withAlphaComponent(0.53),
        state: state
      )
    }

    if owner.isLockHintActive {
      drawLine(
        "Locked",
        y: 6,
        size: 14,
        bold: false,
        color: NSColor.white.withAlphaComponent(0.9),
        state: state
      )
    }

    drawProgress(state: state, context: context)
  }

  private func drawLine(
    _ text: String,
    y: CGFloat,
    size: CGFloat,
    bold: Bool,
    color: NSColor,
    state: LyricWindowState
  ) {
    let inset: CGFloat = 24
    let rect = NSRect(x: inset, y: y, width: bounds.width - inset * 2, height: size * 1.4)

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = state.alignment == "left"
      ? .left
      : state.alignment == "right" ? .right : .center
    paragraph.lineBreakMode = .byTruncatingTail

    let font = state.fontFamily.flatMap { NSFont(name: $0, size: size) }
      ?? NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)

    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
      .paragraphStyle: paragraph,
      // A negative stroke width means "stroke and fill": that is the outline
      // that keeps the lyric readable over a bright video.
      .strokeColor: state.strokeColor,
      .strokeWidth: -max(1, state.strokeWidth),
    ]

    NSAttributedString(string: text, attributes: attributes).draw(in: rect)
  }

  private func layoutControls(width: CGFloat) {
    controlAreas.removeAll()

    let size: CGFloat = 26
    let gap: CGFloat = 8
    let actions = ["previous", "toggle_play", "next", "lock", "close"]
    let total = CGFloat(actions.count) * size + CGFloat(actions.count - 1) * gap

    var x = (width - total) / 2
    let y: CGFloat = 4

    for action in actions {
      controlAreas.append((action, NSRect(x: x, y: y, width: size, height: size)))
      x += size + gap
    }
  }

  private func drawControls(state: LyricWindowState) {
    for area in controlAreas {
      var action = area.action

      if action == "toggle_play" {
        action = state.playing ? "toggle_pause" : "toggle_play"
      }

      drawGlyph(action, in: area.rect, color: NSColor.white.withAlphaComponent(0.9))
    }
  }

  /// Draws one button shape; see the Linux/Windows implementations for why
  /// these are paths and not an icon font.
  private func drawGlyph(_ action: String, in rect: NSRect, color: NSColor) {
    color.setFill()
    color.setStroke()

    let cx = rect.midX
    let cy = rect.midY
    let r = min(rect.width, rect.height) / 2

    switch action {
    case "toggle_play":
      let path = NSBezierPath()
      path.move(to: NSPoint(x: cx - r * 0.6, y: cy - r))
      path.line(to: NSPoint(x: cx - r * 0.6, y: cy + r))
      path.line(to: NSPoint(x: cx + r * 0.9, y: cy))
      path.close()
      path.fill()

    case "toggle_pause":
      NSBezierPath(rect: NSRect(x: cx - r * 0.7, y: cy - r, width: r * 0.5, height: r * 2)).fill()
      NSBezierPath(rect: NSRect(x: cx + r * 0.2, y: cy - r, width: r * 0.5, height: r * 2)).fill()

    case "previous", "next":
      let direction: CGFloat = action == "previous" ? -1 : 1
      let path = NSBezierPath()
      path.move(to: NSPoint(x: cx + direction * r * 0.9, y: cy - r))
      path.line(to: NSPoint(x: cx + direction * r * 0.9, y: cy + r))
      path.line(to: NSPoint(x: cx - direction * r * 0.4, y: cy))
      path.close()
      path.fill()

      NSBezierPath(
        rect: NSRect(
          x: cx - direction * r * 1.1 - r * 0.12,
          y: cy - r,
          width: r * 0.24,
          height: r * 2
        )
      ).fill()

    case "close":
      let path = NSBezierPath()
      path.lineWidth = max(1.5, r * 0.18)
      path.move(to: NSPoint(x: cx - r * 0.6, y: cy - r * 0.6))
      path.line(to: NSPoint(x: cx + r * 0.6, y: cy + r * 0.6))
      path.move(to: NSPoint(x: cx + r * 0.6, y: cy - r * 0.6))
      path.line(to: NSPoint(x: cx - r * 0.6, y: cy + r * 0.6))
      path.stroke()

    default:
      // "lock": a padlock — body plus shackle.
      let bodyWidth = r * 1.3
      let bodyHeight = r * 0.9

      NSBezierPath(
        rect: NSRect(
          x: cx - bodyWidth / 2,
          y: cy - bodyHeight * 0.15,
          width: bodyWidth,
          height: bodyHeight
        )
      ).fill()

      let shackle = NSBezierPath()
      shackle.lineWidth = max(1.5, r * 0.2)
      shackle.appendArc(
        withCenter: NSPoint(x: cx, y: cy - bodyHeight * 0.15),
        radius: bodyWidth * 0.35,
        startAngle: 180,
        endAngle: 0
      )
      shackle.stroke()
    }
  }

  private func drawProgress(state: LyricWindowState, context: CGContext) {
    guard state.hasLyrics else { return }

    let margin: CGFloat = 16
    let barHeight: CGFloat = 3
    let y = bounds.height - barHeight - 6
    let progress = CGFloat(max(0, min(1, state.progress)))

    context.setFillColor(NSColor.white.withAlphaComponent(0.25).cgColor)
    context.fill(CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: barHeight))

    context.setFillColor(NSColor.white.withAlphaComponent(0.8).cgColor)
    context.fill(
      CGRect(x: margin, y: y, width: (bounds.width - margin * 2) * progress, height: barHeight)
    )
  }

  // MARK: - Interaction

  private func hitTestControls(_ point: NSPoint) -> String? {
    guard owner?.controlsVisible == true else { return nil }

    for area in controlAreas where area.rect.contains(point) {
      return area.action
    }

    return nil
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)

    pressedAction = hitTestControls(point)

    guard pressedAction == nil, owner?.currentState.locked == false else { return }

    dragging = true
    dragMouseOrigin = NSEvent.mouseLocation
    dragWindowOrigin = window?.frame.origin ?? .zero
  }

  override func mouseDragged(with event: NSEvent) {
    guard dragging, let window = window else { return }

    let current = NSEvent.mouseLocation

    window.setFrameOrigin(
      NSPoint(
        x: dragWindowOrigin.x + (current.x - dragMouseOrigin.x),
        y: dragWindowOrigin.y + (current.y - dragMouseOrigin.y)
      )
    )
  }

  override func mouseUp(with event: NSEvent) {
    if dragging {
      dragging = false

      return
    }

    guard let action = pressedAction else { return }

    pressedAction = nil

    // The play/pause button is drawn from the playing state and collapses back
    // to "toggle" for the Dart protocol.
    owner?.emit(action == "toggle_play" || action == "toggle_pause" ? "toggle" : action)
  }
}
