import 'package:media_core_cast_dlna/src/domain/enums/dlna_transport_state.dart';
import 'package:media_core_cast_dlna/src/utils/duration_parser.dart';
import 'package:xml/xml.dart';

/// One GENA NOTIFY, decoded (§14.4).
///
/// [variables] is the flattened state the device pushed: direct
/// PropertySet variables (`TransportState`, `RelativeTimePosition`,
/// ...) with AVT/RCS `LastChange` documents unfolded into the same
/// shape, so a consumer reads one map regardless of which event style
/// the firmware uses.
final class GenaNotification {
  /// Creates a notification.
  const GenaNotification({required this.sid, required this.seq, required this.variables});

  /// The subscription this notification belongs to.
  final String sid;

  /// The event sequence number; events are deduplicated against it.
  final int seq;

  /// The state variables carried by this event.
  final Map<String, String> variables;
}

/// Decodes GENA NOTIFY bodies.
abstract final class GenaMessageParser {
  /// Parses a PropertySet document into variables.
  ///
  /// Matching is by local name, as everywhere else in this package;
  /// unparseable bodies yield an empty map — a broken event is dropped,
  /// not escalated.
  static Map<String, String> parsePropertySet(String body) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException {
      return const <String, String>{};
    }
    final variables = <String, String>{};
    for (final element in document.rootElement.descendantElements) {
      if (element.localName != 'property') {
        continue;
      }
      for (final child in element.childElements) {
        final value = child.innerText.trim();
        if (child.localName == 'LastChange') {
          variables.addAll(parseLastChange(value));
        } else {
          variables[child.localName] = value;
        }
      }
    }
    return variables;
  }

  /// Flattens an AVT/RCS `LastChange` document: every element carrying
  /// a `val` attribute becomes `localName → val`, which is the shape
  /// AVTransport:1 and RenderingControl:1 eventing actually uses.
  static Map<String, String> parseLastChange(String xml) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException {
      return const <String, String>{};
    }
    final variables = <String, String>{};
    for (final element in document.rootElement.descendantElements) {
      final value = element.getAttribute('val');
      if (value != null) {
        variables[element.localName] = value;
      }
    }
    return variables;
  }
}

/// Convenience readers over a decoded variable map.
extension GenaNotificationVariables on Map<String, String> {
  /// The transport state, when the event carried a readable one.
  DlnaTransportState? get transportState {
    final raw = this['TransportState'];
    if (raw == null) {
      return null;
    }
    final state = DlnaTransportState.fromUpnp(raw);
    return state == DlnaTransportState.unknown ? null : state;
  }

  /// The playhead position, when the event carried a readable clock.
  Duration? get position => DurationCodec.tryParse(this['RelativeTimePosition'] ?? this['AbsoluteTimePosition']);

  /// The track duration, when the event carried a readable clock.
  Duration? get duration => DurationCodec.tryParse(this['CurrentTrackDuration'] ?? this['MediaDuration']);

  /// The loaded track URI, when the event carried one.
  String? get trackUri {
    final value = this['CurrentTrackURI'] ?? this['AVTURI'];
    if (value == null || value.isEmpty || value.toUpperCase() == 'NOT_IMPLEMENTED') {
      return null;
    }
    return value;
  }
}
