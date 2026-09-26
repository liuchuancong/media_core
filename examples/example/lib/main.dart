import 'package:flutter/material.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_logging/media_core_logging.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';

import 'demos/registry.dart';
import 'language.dart';
import 'ui/module_catalog_page.dart';

/// media_core example: a runnable tour of the framework.
///
/// Two kinds of entry, on purpose:
///
/// - **可运行示例 / Runnable demos** — real pages that create a player and play
///   media (player, live, feed, music, presentation). These are what a
///   developer debugs against, and what shows the intended wiring end to end.
/// - **模块速览 / Module tour** — one page per module with a snippet and a
///   runnable function that prints what the module did. Useful for the
///   pure-logic modules (lyrics parsing, queue rules, source resolution) that
///   need no device and no network to demonstrate.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // media_kit loads libmpv; the example drives the vendored copy in this repo.
  MediaKitPlayerAdapter.ensureInitialized();

  // Framework logs are silent by default (a release build prints nothing).
  // The example turns them on so a developer can watch what the framework
  // decides while pressing buttons.
  MediaCoreLog.level = LogLevel.debug;

  runApp(const MediaCoreExampleApp());
}

/// The example application.
class MediaCoreExampleApp extends StatefulWidget {
  /// Creates the example application.
  const MediaCoreExampleApp({super.key});

  @override
  State<MediaCoreExampleApp> createState() => _MediaCoreExampleAppState();
}

final class _MediaCoreExampleAppState extends State<MediaCoreExampleApp> {
  final DemoLanguageNotifier _language = DemoLanguageNotifier(DemoLanguage.zh);

  @override
  void dispose() {
    _language.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoLanguageScope(
      notifier: _language,
      child: MaterialApp(
        title: 'media_core example',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        ),
        home: ModuleCatalogPage(entries: runnableDemos),
      ),
    );
  }
}
