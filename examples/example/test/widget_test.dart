import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

/// Smoke test: the example boots and lists its runnable demos.
///
/// Deliberately shallow — it touches no player and no native library, so it
/// runs anywhere `flutter test` does. Its job is to catch a broken catalog
/// wiring before a developer launches a device build.
void main() {
  testWidgets('catalog lists the runnable demos', (tester) async {
    await tester.pumpWidget(const MediaCoreExampleApp());

    expect(find.text('可运行示例'), findsOneWidget);
    expect(find.text('播放器与生命周期'), findsOneWidget);
    expect(find.text('音乐：队列 / 歌词 / 桌面歌词 / 后台 / 下载'), findsOneWidget);
  });
}
