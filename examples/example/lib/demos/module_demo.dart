/// Base contract every module demo implements.
///
/// A demo bundles:
/// - bilingual metadata (name / purpose / key points)
/// - a representative Dart snippet
/// - a runnable function that produces console-style output
abstract class ModuleDemo {
  const ModuleDemo();

  /// Stable identifier, e.g. `identity`.
  String get id;

  /// Catalog group the module belongs to.
  ModuleCategory get category;

  /// Display name.
  String get nameZh;
  String get nameEn;

  /// What this module is for (2-4 sentences).
  String get purposeZh;
  String get purposeEn;

  /// Key classes / usage points.
  List<String> get pointsZh;
  List<String> get pointsEn;

  /// Representative Dart snippet shown in the page.
  String get snippet;

  /// Runs the demo and returns console-style output.
  Future<String> run();
}

/// Catalog groups shown on the home page.
enum ModuleCategory {
  foundation('基础模型', 'Foundation'),
  playbackChain('播放链路', 'Playback chain'),
  control('控制与策略', 'Control & policy'),
  failure('失败处理', 'Failure handling'),
  capability('能力扩展', 'Capabilities');

  const ModuleCategory(this.labelZh, this.labelEn);

  final String labelZh;
  final String labelEn;
}
