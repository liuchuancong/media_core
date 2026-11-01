import 'package:media_core_cast_dlna/src/domain/enums/upnp_error_code.dart';

import 'package:xml/xml.dart';

/// A decoded UPnP SOAP fault.
final class SoapFault {
  /// Creates a fault.
  const SoapFault({this.faultCode, this.faultString, this.errorCode, this.errorDescription});

  /// Outer SOAP fault code.
  final String? faultCode;

  /// Outer SOAP fault string.
  final String? faultString;

  /// UPnP control error code as sent (`401`, `701`, ...).
  final String? errorCode;

  /// UPnP control error description.
  final String? errorDescription;

  /// The numeric UPnP error code, when it parses as an integer.
  int? get codeNumber => errorCode == null ? null : int.tryParse(errorCode!);

  /// The classified UPnP error code.
  UpnpErrorCode get code => UpnpErrorCode.fromRaw(codeNumber);

  @override
  String toString() => 'SoapFault($errorCode ${errorDescription ?? faultString ?? faultCode ?? ''})';
}

/// Extracts a UPnP fault from a SOAP response body.
abstract final class SoapFaultParser {
  /// Returns the decoded fault, or null when the body carries none.
  ///
  /// A body that is not XML at all is "no fault" rather than an error:
  /// the fault check runs before status-code handling, and half the
  /// non-2xx answers on the wire are HTML error pages, not SOAP.
  static SoapFault? parse(String body) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException {
      return null;
    }

    final fault = _descendant(document.rootElement, 'Fault');
    if (fault == null) {
      return null;
    }
    final detail = _descendant(fault, 'detail');
    final upnp = detail == null ? null : _firstChildElement(detail);
    return SoapFault(
      faultCode: _descendant(fault, 'faultCode')?.innerText.trim(),
      faultString: _descendant(fault, 'faultString')?.innerText.trim(),
      errorCode: upnp == null ? null : _descendant(upnp, 'errorCode')?.innerText.trim(),
      errorDescription: upnp == null ? null : _descendant(upnp, 'errorDescription')?.innerText.trim(),
    );
  }

  static XmlElement? _descendant(XmlElement root, String localName) {
    for (final element in root.descendantElements) {
      if (element.localName == localName) {
        return element;
      }
    }
    return null;
  }

  static XmlElement? _firstChildElement(XmlElement parent) {
    for (final child in parent.children.whereType<XmlElement>()) {
      return child;
    }
    return null;
  }
}
