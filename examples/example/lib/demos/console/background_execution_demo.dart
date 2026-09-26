import 'dart:async';

import 'package:media_core_native/media_core_native.dart';

import '../module_demo.dart';

/// Holding a background-execution session: what a recording or a download
/// needs to survive the screen going off.
///
/// The demo acquires two sessions, prints what the platform answered, and
/// releases them one at a time so the difference is observable in the
/// notification shade: on Android the two share one notification that says
/// `+1`, and releasing the first leaves the second one protected. Run it on a
/// phone, pull the shade down while it runs, and the printed lines and the
/// notification are the same story.
class BackgroundExecutionDemo extends ModuleDemo {
  /// Creates the demo.
  const BackgroundExecutionDemo();

  @override
  String get id => 'background-execution';

  @override
  ModuleCategory get category => ModuleCategory.capability;

  @override
  String get nameZh => '后台保活（通知 / 唤醒锁 / 多会话）';

  @override
  String get nameEn => 'Background keep-alive (notification, wake lock, sessions)';

  @override
  String get purposeZh =>
      '录制和下载是"用户要了就不再盯着"的任务：屏幕一关，系统几秒内就冻结或杀掉进程，任务只留下一个说不清原因的退出码。会话对象把"谁负责收回这份保护"变成一次 release —— Android 上就是一条前台服务通知加一把部分唤醒锁，iOS/macOS/Windows 上是"别睡"的断言，Linux 还没有实现（如实返回 null）。';

  @override
  String get purposeEn =>
      'Recording and downloading are jobs the user asked for and then stopped watching: without a session the platform freezes or kills the process seconds after the screen goes off, leaving nothing but an exit code that explains nothing. A session object turns "who releases this protection" into one release call — a foreground-service notification plus a partial wake lock on Android, a sleep assertion on iOS/macOS/Windows, and nothing yet on Linux (null, honestly reported).';

  @override
  List<String> get pointsZh => const <String>[
        'isSupported 只回答"这个平台有没有实现"，acquire 才是问"现在能不能给我一份"',
        'Android 13+ 的通知权限由这个包自己在有 Activity 时弹出；拒绝也照跑 —— 唤醒锁还在，只是看不到通知',
        '两个任务同时跑共享一个前台服务与一条通知（标题后面标 +1），释放一个不会拆掉另一个的保护',
        'release 幂等：失败路径、二次结束、进程已经被杀，都不会去动别人的会话',
        'iOS 拿到的是"转场窗口"（约 30 秒），不是无限时间；长时间录制要应用自己声明 audio 后台模式',
        'kind 决定通知图标（record / download / task），因为下载箭头出现在录制通知上就是一句假话',
      ];

  @override
  List<String> get pointsEn => const <String>[
        'isSupported answers "does this platform implement it"; acquire asks "will it give me one right now"',
        'On Android 13+ this package asks for the notification permission itself while an activity is attached; a refusal still runs the job — the wake lock holds, only the notification stays hidden',
        'Two jobs share one foreground service and one notification (the title carries a +1), and releasing one does not take the other one apart',
        'release is idempotent: a failed path, a second end, or a process that was already killed never touches somebody else\'s session',
        'On iOS the assertion buys the transition window (about 30 seconds), not unlimited time; a long recording needs the app\'s own audio background mode',
        'kind picks the notification icon (record / download / task), because a download arrow on a recording is a small lie',
      ];

  @override
  String get snippet => '''
final session = await BackgroundExecution.acquire(
  title: '正在录制',
  text: 'room-42',
  kind: BackgroundJobKind.record,
);

try {
  await startTheJob();
} finally {
  await session?.release();   // 会话对象就是"谁来收回"的答案
}
''';

  /// How long each phase is held, so the notification can be looked at.
  static const Duration _hold = Duration(seconds: 2);

  @override
  Future<String> run() async {
    final buffer = StringBuffer();

    buffer.writeln('BackgroundExecution.isSupported: ${BackgroundExecution.isSupported}');

    if (!BackgroundExecution.isSupported) {
      buffer.writeln('这个平台没有实现：任务照跑，只是没有保护（不是失败）。');
      buffer.writeln('No implementation here: the job still runs, just unprotected (not a failure).');
      return buffer.toString();
    }

    buffer.writeln('— 取得第一个会话（录制）/ first session (recording) —');

    final recording = await BackgroundExecution.acquire(
      title: '演示：保存直播',
      text: 'demo_recording',
      kind: BackgroundJobKind.record,
    );

    buffer.writeln('acquire -> $recording');

    if (recording == null) {
      buffer.writeln('平台拒绝了前台服务：录制仍会继续，只是屏幕一关就可能被冻结。');
      buffer.writeln('The platform refused the foreground service: the recording continues, but may be frozen once the screen goes off.');
      return buffer.toString();
    }

    // Held open for the second phase so both sessions are alive at once.
    try {
      buffer.writeln('');
      buffer.writeln('通知栏现在应该有一条常驻通知（Android）。');
      buffer.writeln('A persistent notification should be in the shade now (Android).');
      buffer.writeln('— 同时再取一个（下载）/ a second one at the same time (download) —');

      final download = await BackgroundExecution.acquire(
        title: '演示：下载大文件',
        text: 'demo_download',
        kind: BackgroundJobKind.download,
      );

      buffer.writeln('acquire -> $download');
      buffer.writeln('两个会话共享一条通知：标题是后取的那个，正文标 +1。');
      buffer.writeln('Both share one notification: the newest title, with +1 for the other.');

      await Future<void>.delayed(_hold);

      buffer.writeln('');
      buffer.writeln('— 释放下载会话，录制的保护应当还在 —');
      await download?.release();
      buffer.writeln('released -> $download');

      await Future<void>.delayed(_hold);
    } finally {
      // Every path out of here releases, which is the whole point of a session
      // object: the protection cannot outlive the job that asked for it.
      await recording.release();
      buffer.writeln('');
      buffer.writeln('— 全部释放，通知消失 —');
      buffer.writeln('released -> $recording');
    }

    return buffer.toString();
  }
}
