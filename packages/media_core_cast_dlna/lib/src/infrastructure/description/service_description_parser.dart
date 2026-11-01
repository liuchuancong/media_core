import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';

import 'package:xml/xml.dart';

/// One argument of an SCPD-declared action.
final class ScpdArgument {
  /// Creates an argument.
  const ScpdArgument({required this.name, required this.direction, this.relatedStateVariable});

  /// The argument name, matched literally by devices.
  final String name;

  /// `in` for inputs, `out` for outputs.
  final String direction;

  /// The state variable typing this argument, when declared.
  final String? relatedStateVariable;
}

/// One action an SCPD declares.
final class ScpdAction {
  /// Creates an action.
  const ScpdAction({required this.name, this.arguments = const <ScpdArgument>[]});

  /// The action name, exactly as the device accepts it on the wire.
  final String name;

  /// The declared arguments.
  final List<ScpdArgument> arguments;
}

/// One state variable of an SCPD.
final class ScpdStateVariable {
  /// Creates a state variable.
  const ScpdStateVariable({required this.name, this.dataType, this.allowedValues = const <String>[]});

  /// The variable name.
  final String name;

  /// The UPnP data type (`string`, `ui4`, ...), when declared.
  final String? dataType;

  /// The values the device restricts itself to, when it declares an
  /// allowed value list.
  final List<String> allowedValues;
}

/// The actions and state variables a device's SCPD declares.
///
/// This is the authority on what a service can do: an action name that
/// exists in the UPnP specification but not in this device's SCPD is
/// an action the device will refuse — the capability check reads from
/// here, never from the spec.
final class ServiceDescription {
  /// Creates a description.
  const ServiceDescription({required this.actions, required this.stateVariables});

  /// The declared actions, keyed by name.
  final Map<String, ScpdAction> actions;

  /// The declared state variables, keyed by name.
  final Map<String, ScpdStateVariable> stateVariables;

  /// Whether the service declares [action].
  bool supportsAction(String action) => actions.containsKey(action);
}

/// Parses an UPnP SCPD (service control protocol description) document.
abstract final class ServiceDescriptionParser {
  /// Parses an SCPD document.
  ///
  /// Matching is by local name, as with device descriptions: SCPD
  /// namespaces are consistent in the spec and inconsistent on real
  /// firmware. A document that parses as XML but declares nothing is
  /// an empty service, not an error — the capability check then
  /// reports "unsupported" instead of the fetch layer shouting.
  static ServiceDescription parse(String xml) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException catch (error) {
      throw DlnaServiceDescriptionException('service description is not valid XML', cause: error);
    }

    final actions = <String, ScpdAction>{};
    final variables = <String, ScpdStateVariable>{};

    for (final element in document.rootElement.descendantElements) {
      switch (element.localName) {
        case 'action':
          final action = _parseAction(element);
          if (action != null) {
            actions[action.name] = action;
          }
        case 'stateVariable':
          final variable = _parseStateVariable(element);
          if (variable != null) {
            variables[variable.name] = variable;
          }
      }
    }

    return ServiceDescription(actions: actions, stateVariables: variables);
  }

  static ScpdAction? _parseAction(XmlElement element) {
    final name = _childText(element, 'name')?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    final arguments = <ScpdArgument>[];
    for (final list in element.childElements) {
      if (list.localName != 'argumentList') {
        continue;
      }
      for (final argument in list.childElements) {
        if (argument.localName != 'argument') {
          continue;
        }
        final argumentName = _childText(argument, 'name')?.trim();
        if (argumentName == null || argumentName.isEmpty) {
          continue;
        }
        arguments.add(
          ScpdArgument(
            name: argumentName,
            direction: (_childText(argument, 'direction')?.trim() ?? 'in').toLowerCase(),
            relatedStateVariable: _childText(argument, 'relatedStateVariable')?.trim(),
          ),
        );
      }
    }
    return ScpdAction(name: name, arguments: arguments);
  }

  static ScpdStateVariable? _parseStateVariable(XmlElement element) {
    final name = _childText(element, 'name')?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    final allowed = <String>[];
    for (final list in element.childElements) {
      if (list.localName != 'allowedValueList') {
        continue;
      }
      for (final value in list.childElements) {
        if (value.localName == 'allowedValue') {
          final text = value.innerText.trim();
          if (text.isNotEmpty) {
            allowed.add(text);
          }
        }
      }
    }
    return ScpdStateVariable(name: name, dataType: _childText(element, 'dataType')?.trim(), allowedValues: allowed);
  }

  static String? _childText(XmlElement parent, String name) {
    for (final child in parent.childElements) {
      if (child.localName == name) {
        return child.innerText;
      }
    }
    return null;
  }
}
