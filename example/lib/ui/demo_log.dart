import 'package:flutter/material.dart';

/// A tiny in-page event log.
///
/// Every demo page shows what the framework reported while the developer
/// pressed buttons — adapter events, recovery decisions, download progress.
/// A log is the cheapest honest way to make framework behaviour visible
/// without inventing a UI for each module.
final class DemoLog extends ChangeNotifier {
  DemoLog({this.maxLines = 200});

  /// How many lines are kept.
  final int maxLines;

  final List<String> _lines = <String>[];

  /// Most recent line first.
  List<String> get lines => List<String>.unmodifiable(_lines);

  /// Whether anything was logged.
  bool get isEmpty => _lines.isEmpty;

  /// Adds one line, timestamped to the second.
  void add(String message) {
    final now = DateTime.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    _lines.insert(0, '$stamp  $message');

    while (_lines.length > maxLines) {
      _lines.removeLast();
    }

    notifyListeners();
  }

  /// Clears the log.
  void clear() {
    _lines.clear();
    notifyListeners();
  }
}

/// Shows a [DemoLog] as a scrolling monospace panel.
class DemoLogPanel extends StatelessWidget {
  /// Creates the panel.
  const DemoLogPanel({required this.log, super.key, this.height = 180});

  /// The log to render.
  final DemoLog log;

  /// Panel height.
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: AnimatedBuilder(
          animation: log,
          builder: (context, _) {
            if (log.isEmpty) {
              return const Center(
                child: Text('事件日志 / event log', style: TextStyle(fontSize: 12, color: Colors.grey)),
              );
            }

            return ListView.builder(
              reverse: false,
              itemCount: log.lines.length,
              itemBuilder: (context, index) => Text(
                log.lines[index],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            );
          },
        ),
      ),
    );
  }
}
