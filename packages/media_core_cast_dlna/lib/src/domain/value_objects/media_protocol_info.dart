import 'package:meta/meta.dart';

/// A parsed `protocol:network:contentFormat:additionalInfo` string.
///
/// This is the vocabulary DLNA devices use to say what they can play
/// (`http-get:*:video/mp4:DLNA.ORG_OP=01;DLNA.ORG_CI=0`) and what a
/// resource is. The colon structure is positional, and the additional
/// info carries the DLNA parameters — splitting naively on `:` loses
/// them, so this type parses all four fields and then decodes the
/// `DLNA.ORG_*` parameters individually.
@immutable
final class MediaProtocolInfo {
  /// Creates a parsed protocol info.
  const MediaProtocolInfo({
    required this.protocol,
    required this.network,
    required this.contentFormat,
    this.additionalInfo = '',
  });

  /// The transfer protocol (`http-get`, `rtsp-rtp-udp`, ...).
  final String protocol;

  /// The network field (usually `*`).
  final String network;

  /// The content MIME type (`video/mp4`, `*`, ...).
  final String contentFormat;

  /// Everything after the third colon, raw
  /// (`DLNA.ORG_OP=01;DLNA.ORG_CI=0`).
  final String additionalInfo;

  /// Parses one protocol-info string; null when the structure is not
  /// the four-field shape at all.
  static MediaProtocolInfo? tryParse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final first = value.indexOf(':');
    if (first < 0) {
      return null;
    }
    final second = value.indexOf(':', first + 1);
    if (second < 0) {
      return null;
    }
    final third = value.indexOf(':', second + 1);
    if (third < 0) {
      return null;
    }
    return MediaProtocolInfo(
      protocol: value.substring(0, first).trim(),
      network: value.substring(first + 1, second).trim(),
      contentFormat: value.substring(second + 1, third).trim(),
      additionalInfo: value.substring(third + 1).trim(),
    );
  }

  /// Parses a `GetProtocolInfo` Sink (or Source) value: the entries are
  /// separated by commas or newlines depending on the firmware, and a
  /// trailing comma is common. Unparseable entries are skipped — one
  /// broken line must not erase the rest of the list.
  static List<MediaProtocolInfo> parseList(String raw) {
    final entries = <MediaProtocolInfo>[];
    for (final line in raw.split(RegExp(r'[\r\n,]'))) {
      final parsed = tryParse(line);
      if (parsed != null) {
        entries.add(parsed);
      }
    }
    return entries;
  }

  /// The `DLNA.ORG_PN` profile name, when declared.
  String? get dlnaProfile => _parameter('DLNA.ORG_PN');

  /// The `DLNA.ORG_OP` operations bits, when declared.
  ///
  /// Bit 0 (value `& 1`) is byte-range support, bit 1 is time-seek
  /// range support; `0` means neither.
  int? get operations => _intParameter('DLNA.ORG_OP');

  /// The `DLNA.ORG_CI` conversion indicator: `1` means the resource is
  /// a transcoded (converted) form of the original.
  int? get conversionIndicator => _intParameter('DLNA.ORG_CI');

  /// The `DLNA.ORG_FLAGS` capability flags, when declared.
  int? get flags => _intParameter('DLNA.ORG_FLAGS');

  /// Whether the declared operations include byte-range support.
  ///
  /// An entry without `DLNA.ORG_OP` at all is treated as
  /// range-capable: most real sink lists omit the parameter for plain
  /// entries, and assuming the worst would disqualify every device
  /// that did not bother to spell it out.
  bool get supportsByteRange {
    final value = operations;
    return value == null || value & 1 == 1;
  }

  /// Whether this entry declares a converted (transcoded) resource.
  bool get requiresConversion => conversionIndicator == 1;

  String? _parameter(String name) {
    for (final part in additionalInfo.split(';')) {
      final assignment = part.indexOf('=');
      if (assignment <= 0) {
        continue;
      }
      if (part.substring(0, assignment).trim().toUpperCase() == name) {
        return part.substring(assignment + 1).trim();
      }
    }
    return null;
  }

  int? _intParameter(String name) {
    final raw = _parameter(name);
    if (raw == null) {
      return null;
    }
    return int.tryParse(raw, radix: 16) ?? int.tryParse(raw);
  }

  @override
  String toString() => '$protocol:$network:$contentFormat:$additionalInfo';
}
