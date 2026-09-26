import 'package:flutter/material.dart';

/// Application-wide language mode for demo descriptions.
enum DemoLanguage { zh, en }

/// Simple inherited language state with a toggle.
class DemoLanguageScope extends InheritedNotifier<DemoLanguageNotifier> {
  const DemoLanguageScope({
    super.key,
    required DemoLanguageNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static DemoLanguage of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<DemoLanguageScope>();
    return scope?.notifier?.value ?? DemoLanguage.zh;
  }

  /// Toggles the language from anywhere below the scope.
  static void toggle(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<DemoLanguageScope>();
    scope?.notifier?.toggle();
  }
}

class DemoLanguageNotifier extends ChangeNotifier {
  DemoLanguageNotifier(this._value);

  DemoLanguage _value;

  DemoLanguage get value => _value;

  void toggle() {
    _value = _value == DemoLanguage.zh ? DemoLanguage.en : DemoLanguage.zh;
    notifyListeners();
  }
}
