import 'package:xml/xml.dart';

/// Decodes output arguments from a SOAP action response.
abstract final class SoapResponseParser {
  /// Reads a single output argument by local name.
  ///
  /// The XML namespace prefix differs across firmwares (`s:`, `SOAP-ENV:`,
  /// none) while the *local* names do not, so lookups match on local
  /// name; matching by qualified name is the classic way a UPnP client
  /// works on half the devices it ships for. Unparseable bodies yield
  /// null rather than throwing — an answer the device already sent is
  /// data, not a reason to break the caller.
  static String? argument(String body, String name) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException {
      return null;
    }
    for (final element in document.rootElement.descendantElements) {
      if (element.localName == name) {
        return element.innerText.trim();
      }
    }
    return null;
  }

  /// Reads every direct output argument of the response element (the
  /// first element whose local name ends in `Response`).
  ///
  /// Returns an empty map for a body without a recognizable response
  /// element — the caller decides whether that matters.
  static Map<String, String> arguments(String body) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException {
      return const <String, String>{};
    }
    for (final element in document.rootElement.descendantElements) {
      if (element.localName.endsWith('Response')) {
        final values = <String, String>{};
        for (final child in element.childElements) {
          values[child.localName] = child.innerText.trim();
        }
        return values;
      }
    }
    return const <String, String>{};
  }
}
