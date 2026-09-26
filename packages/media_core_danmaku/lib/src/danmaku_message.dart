/// Message kinds a danmaku transport can deliver.
///
/// [chat], [gift] and [superChat] are platform messages. [system] is composed
/// locally — connection notices, filter feedback — and never carries a
/// platform identity, so it is exempt from filtering.
///
/// [audience] is tolerated for transport parity: some platforms multiplex
/// viewer metrics and chat on one socket, and dropping the packet at the
/// transport would lose the metric. Audience numbers themselves are owned by
/// the live layer, not by this module; the payload is carried here only so a
/// caller can forward it without re-parsing the socket.
enum DanmakuMessageType { chat, gift, superChat, audience, system }

/// Where a message is anchored on screen.
enum DanmakuPlacement { scroll, top, bottom }

/// RGB color of a platform message.
///
/// Platform protocols disagree on how they encode color: some send a packed
/// integer, some a hex string whose leading zero is dropped. Both shapes are
/// accepted by [DanmakuColor.fromInt] and [DanmakuColor.parse] so a transport
/// never has to normalize before handing a packet over.
final class DanmakuColor {
  const DanmakuColor(this.r, this.g, this.b);

  /// Default color for messages that carry none.
  static const DanmakuColor white = DanmakuColor(255, 255, 255);

  final int r;
  final int g;
  final int b;

  /// Decodes a packed `0xRRGGBB` integer.
  ///
  /// Values outside 0..0xFFFFFF are masked rather than rejected: a malformed
  /// packet should still render as *something* instead of dropping the message.
  factory DanmakuColor.fromInt(int value) {
    final masked = value & 0xFFFFFF;
    return DanmakuColor((masked >> 16) & 0xFF, (masked >> 8) & 0xFF, masked & 0xFF);
  }

  /// Decodes the hex-string form platforms use.
  ///
  /// Handles the three shapes seen in the wild: `RGB`, `RRGGBB` and
  /// `AARRGGBB` (alpha is ignored — danmaku opacity is a per-viewer setting,
  /// never a platform one). Returns [white] when the string cannot be decoded.
  factory DanmakuColor.parse(String value) {
    var text = value.trim().replaceFirst('#', '').replaceFirst(RegExp('^0x'), '');
    if (text.length == 3) {
      text = text.split('').map((char) => '$char$char').join();
    }
    if (text.length == 6) {
      text = '00$text';
    }
    if (text.length != 8) return white;
    final parsed = int.tryParse(text, radix: 16);
    if (parsed == null) return white;
    return DanmakuColor((parsed >> 16) & 0xFF, (parsed >> 8) & 0xFF, parsed & 0xFF);
  }

  /// Packs the color into `0xRRGGBB`.
  int toInt() => (r << 16) | (g << 8) | b;

  @override
  String toString() =>
      '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DanmakuColor && other.r == r && other.g == g && other.b == b);

  @override
  int get hashCode => Object.hash(r, g, b);
}

/// Per-message presentation override.
///
/// Platform messages normally follow the room-wide configuration; this exists
/// for locally composed messages ([DanmakuMessageType.system] and paid-message
/// cards) that must look different from the surrounding chat without the host
/// maintaining a second renderer.
final class DanmakuStyle {
  const DanmakuStyle({
    required this.fontSize,
    required this.baseSpeed,
    required this.fontWeight,
    this.showStroke = false,
    this.strokeWidth = 1,
    this.placement = DanmakuPlacement.scroll,
    this.fontFamily,
    this.italic = false,
    this.opacity = 1,
    this.letterSpacing = 0,
    this.strokeColor = 0xFF000000,
    this.showShadow = false,
    this.shadowColor = 0xFF000000,
    this.shadowBlur = 2,
    this.shadowOffset = 1,
    this.fixedDurationMs = 4000,
  });

  /// Em box height.
  final double fontSize;

  /// Logical pixels per second for [DanmakuPlacement.scroll].
  final double baseSpeed;

  final int fontWeight;
  final bool showStroke;
  final double strokeWidth;
  final DanmakuPlacement placement;
  final String? fontFamily;
  final bool italic;
  final double opacity;
  final double letterSpacing;
  final int strokeColor;
  final bool showShadow;
  final int shadowColor;
  final double shadowBlur;
  final double shadowOffset;

  /// On-screen time for fixed ([DanmakuPlacement.top]/[DanmakuPlacement.bottom])
  /// placements, which do not scroll and therefore have no speed.
  final int fixedDurationMs;
}

/// Viewer metric carried alongside chat by single-socket platforms.
///
/// [kind] is explicit because the three numbers are not interchangeable:
/// platform heat, concurrent viewers and cumulative viewers are different
/// measurements, and relabeling one as another silently corrupts every
/// ranking and chart built on top of it.
enum DanmakuAudienceKind { popularity, concurrentViewers, cumulativeViewers }

/// Typed audience update. See [DanmakuMessageType.audience].
final class DanmakuAudienceUpdate {
  const DanmakuAudienceUpdate({required this.kind, required this.value});

  final DanmakuAudienceKind kind;
  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DanmakuAudienceUpdate && other.kind == kind && other.value == value);

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'DanmakuAudienceUpdate(${kind.name}: $value)';
}

/// One danmaku message, normalized across platforms.
///
/// This is the only shape the module's filters, gate and host agree on: a
/// transport must fully decode its platform protocol before constructing it,
/// and must not leave platform-specific fields for the renderer to interpret.
final class DanmakuMessage {
  const DanmakuMessage({
    required this.type,
    required this.userName,
    required this.text,
    this.color = DanmakuColor.white,
    this.userId = '',
    this.userLevel = '',
    this.fansLevel = '',
    this.fansName = '',
    this.isLocal = false,
    this.messageId = '',
    this.sentAt,
    this.style,
    this.audience,
    this.superChat,
  });

  final DanmakuMessageType type;

  /// Display name exactly as the platform sent it.
  ///
  /// A display name is not an identity: different viewers can share one, and
  /// one viewer can rename mid-session. Use [userId] for identity checks.
  final String userName;

  /// Display text exactly as the platform sent it, before any filtering.
  final String text;

  final DanmakuColor color;

  /// Stable viewer identity from the platform, empty when it exposes none.
  final String userId;

  /// Platform-specific level labels, carried for rendering only.
  final String userLevel;
  final String fansLevel;
  final String fansName;

  /// True for messages this client composed (echoes of the viewer's own send,
  /// local notices). Local messages bypass user-facing filters.
  final bool isLocal;

  /// Stable per-message identity from the platform, empty when unavailable.
  ///
  /// When present it drives duplicate suppression: a replayed packet after a
  /// reconnect carries the same id and is dropped, while two genuinely
  /// separate messages that happen to share text stay visible.
  final String messageId;

  /// Platform timestamp, or `null` when the platform exposes none.
  ///
  /// A null timestamp means "order by arrival"; it must not be replaced with
  /// `DateTime.now()` by the transport, because the arrival-time fingerprint
  /// is what [DanmakuMessageGate] falls back to for platforms without ids.
  final DateTime? sentAt;

  final DanmakuStyle? style;

  /// Payload for [DanmakuMessageType.audience], `null` for every other type.
  final DanmakuAudienceUpdate? audience;

  /// Payload for [DanmakuMessageType.superChat], `null` for every other type.
  final DanmakuSuperChat? superChat;

  /// Whether the message carries a usable platform identity for deduplication.
  bool get hasStableId => messageId.trim().isNotEmpty;

  @override
  String toString() =>
      'DanmakuMessage(${type.name}, $userName: $text'
      '${messageId.isEmpty ? '' : ', id: $messageId'})';
}

/// Paid message (super chat / 醒目留言) card content.
///
/// Held apart from [DanmakuMessage] because a paid message is a card with a
/// lifetime, not a line of chat: it has its own identity, price and expiry,
/// and platforms re-send it on every poll until it expires.
final class DanmakuSuperChat {
  const DanmakuSuperChat({
    required this.userName,
    required this.text,
    required this.price,
    required this.startTime,
    required this.endTime,
    required this.backgroundColor,
    required this.backgroundBottomColor,
    this.messageId = '',
    this.face = '',
  });

  /// Stable platform event identity when the protocol exposes one.
  ///
  /// Some message-board APIs rebuild [startTime] from a countdown on every
  /// poll. Time-based equality would then make one paid message look new on
  /// every refresh — and, worse, make a genuinely new message with identical
  /// user/text/price look like a replay.
  final String messageId;

  final String userName;
  final String face;
  final String text;
  final int price;
  final DateTime startTime;
  final DateTime endTime;
  final String backgroundColor;
  final String backgroundBottomColor;

  /// Identity used to coalesce repeated snapshots of the same paid message.
  ///
  /// Falls back to user/text/price only when the platform exposes no id, and
  /// deliberately ignores [startTime] — see [messageId].
  Object get coalesceKey => messageId.isNotEmpty ? messageId : Object.hash(userName, text, price);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DanmakuSuperChat) return false;
    if (messageId.isNotEmpty || other.messageId.isNotEmpty) {
      return messageId.isNotEmpty && other.messageId.isNotEmpty && other.messageId == messageId;
    }
    return other.userName == userName && other.text == text && other.price == price;
  }

  @override
  int get hashCode => messageId.isNotEmpty ? messageId.hashCode : Object.hash(userName, text, price);
}
