import 'package:example/demos/module_demo.dart';
import 'package:media_core/media_core.dart'
    show
        BackgroundAcquireRejected,
        BackgroundAcquireSuccess,
        BackgroundExecutionKind,
        BackgroundLease,
        BackgroundRequest,
        BackgroundServiceOwner,
        MediaJobKind,
        MediaJobOutcome,
        MediaJobReporting,
        MediaJobStart;
import 'package:media_core_native/media_core_native.dart' show NativeBackgroundRuntime;
import 'package:media_core_notify/media_core_notify.dart';

/// Notifications a host actually gets: one running line per feature, and the
/// outcome of the job when it ends.
///
/// The two halves are separate on purpose. The line says "this is still working"
/// and is a projection over the background runtime — the same registry that decides
/// which foreground service holds the job; the outcome says "this finished or did
/// not", and reaches the tray through the reporter the job packages hand their
/// verdict to. `MediaCoreNotify.enable()` installs the second and arms the first.
class NotifyDemo extends ModuleDemo {
  /// Creates the demo.
  const new();

  @override
  String get id => 'notify';

  @override
  ModuleCategory get category => ModuleCategory.capability;

  @override
  String get nameZh => '通知（每功能一条进行中的线 + 作业结果）';

  @override
  String get nameEn => 'Notifications (one running line per feature, plus job results)';

  @override
  String get purposeZh =>
      'main() 里 enable 一次之后，录制、下载、未命名任务各自有一条进行中的线：停掉一个不会改写另一个，"还有 N 个任务"也只数自己那一个功能。Android 上这些线由每个功能自己的前台服务带，本包在那边一字不画；Windows / macOS / Linux 上没有系统服务可依赖，才由这里画。作业结束时的"完成 / 中断"是另一路：下载与录制把结果交给核心登记的 reporter，本包把它翻译成通知。';

  @override
  String get purposeEn =>
      'After one enable() in main(), recording, download and unnamed work each have their own running line: ending one never rewrites another, and the "(N more)" count only counts its own feature. On Android those lines come from each feature’s own foreground service and this package draws nothing; on Windows, macOS and Linux there is no system service to lean on, so it draws them. A finished or interrupted job is a different path: the job packages hand their verdict to the reporter registered in the core.';

  @override
  String get snippet => '''
await MediaCoreNotify.enable();            // installs the reporter, arms the lines
await MediaCoreNotify.requestPermission(); // 只有宿主决定问的时候才问

final lease = await NativeBackgroundRuntime.shared.acquire(BackgroundRequest(
  id: 'recording/room-42', kind: BackgroundExecutionKind.recording,
  title: '正在录制', description: 'room-42 · 00:12',
));
print(ForegroundJobs.bodyFor(BackgroundServiceOwner.recording)); // 只数录制
await lease.release();
''';

  @override
  List<String> get pointsZh => const <String>[
    '每功能一条线：id 与渠道都由 `BackgroundServiceOwner` 派生（media_core_recording / _download / _jobs），静音一个不牵连另一个',
    'Android 上 `ForegroundJobs.drawsLine` 为 false —— 那边的常驻线是每个功能自己的前台服务画的，重复画就是两条内容相同的通知',
    '"还有 N 个任务"数的是同一功能的其他会话，不是全进程的任务总数',
    '开线与收线不节流，只有移动的文字节流：最后一条作业结束还留着的那条线是在说假话',
    '作业结果走核心的 `MediaJobReporting`，所以下载与录制包不需要依赖通知插件；reporter 为 null 就说明宿主没 enable',
    '权限：本包只声明不申请，`requestPermission()` 是唯一入口，`notificationsEnabled()` 是"先看一眼再决定要不要问"',
  ];

  @override
  List<String> get pointsEn => const <String>[
    'One line per feature: the id and channel both come from `BackgroundServiceOwner` (media_core_recording / _download / _jobs), so muting one feature cannot mute another',
    'On Android `ForegroundJobs.drawsLine` is false — each feature’s foreground service already draws that line, and drawing it again is two identical notifications',
    'The "(N more)" count counts the other sessions of the same feature, not every job in the process',
    'Opening and closing a line is never throttled, only the moving text: a line that outlives the last job of its feature is lying',
    'Job results travel through `MediaJobReporting` in the core, which is why the download and recording packages need no notification dependency; a null reporter means the host never enabled it',
    'Permission: declared, never asked here. `requestPermission()` is the only entry point and `notificationsEnabled()` is how you look before deciding to ask',
  ];

  @override
  Future<String> run() async {
    final buffer = StringBuffer()
      ..writeln('MediaCoreNotify.enabled: ${MediaCoreNotify.enabled}')
      ..writeln('渠道 / channels: ${MediaCoreNotify.setup.channels.map((c) => c.id).toList()}')
      // A check, not a question — asking is the app's decision, and this demo does
      // not have the right to put a system dialog in front of the user.
      ..writeln('notificationsEnabled()（只查不问）: ${await MediaCoreNotify.notificationsEnabled()}');

    if (!MediaCoreNotify.enabled) {
      buffer.writeln(
        '没 enable：结果没人收、线没人画。main() 里那一行是整个应用在通知上做的全部集成。',
      );

      return buffer.toString();
    }

    buffer
      ..writeln()
      ..writeln('— 1. 两个功能各取一条后台会话 —');
    final runtime = NativeBackgroundRuntime.shared;
    final recording = await runtime.acquire(
      const BackgroundRequest(
        id: 'recording/demo',
        kind: BackgroundExecutionKind.recording,
        title: '演示：正在录制',
        description: 'room-42 · 00:12',
      ),
    );
    BackgroundLease? downloadLease;

    buffer.writeln('recording acquire -> ${recording.runtimeType}');
    if (recording is! BackgroundAcquireSuccess) {
      buffer
        ..writeln('这个平台没给后台会话（Linux 还没有实现），后面的线也就无从投影。')
        ..writeln('拒绝原因 / refusal: ${recording is BackgroundAcquireRejected ? recording.reason.name : '未知'}');

      return buffer.toString();
    }

    final download = await runtime.acquire(
      const BackgroundRequest(
        id: 'download/demo',
        kind: BackgroundExecutionKind.download,
        title: '演示：正在下载',
        description: 'vlog.ts · 45%',
        priority: 5,
      ),
    );
    if (download is BackgroundAcquireSuccess) {
      downloadLease = download.lease;
    }
    buffer.writeln('download acquire -> ${download.runtimeType}');

    await _settle();
    _writeLines(buffer, '两个功能同时在跑');

    buffer
      ..writeln()
      ..writeln('— 2. 释放下载：录制那一行不该被改写 —');
    await downloadLease?.release();
    await _settle();
    _writeLines(buffer, '下载已结束');

    buffer
      ..writeln()
      ..writeln('— 3. 作业结果走 reporter，不依赖通知插件 —');
    final reporter = MediaJobReporting.reporter;
    if (reporter == null) {
      buffer.writeln('MediaJobReporting.reporter == null：enable() 没装它，下载与录制的结果就没人收。');
    } else {
      reporter
        ..reportStart(const MediaJobStart(kind: MediaJobKind.download, label: 'vlog.ts'))
        ..report(
          const MediaJobOutcome(
            kind: MediaJobKind.download,
            label: 'vlog.ts',
            success: true,
            bytesWritten: 128 * 1024 * 1024,
            elapsed: Duration(minutes: 3, seconds: 41),
          ),
        );
      buffer
        ..writeln('已上报一条"开始下载"和一条"下载完成"（都在 media_core_results 渠道）')
        ..writeln('开始贴不贴由宿主给的 policy 决定：默认的 results 把它静音，要听就用 startsAndResults。')
        ..writeln('开始是 reporter 上另一个方法，不是一条 success 没填的记录——不然只读结论的宿主会把"刚开始"念成"已完成"。')
        ..writeln('录制结束、中断、失败也是同一条路：由作业包自己说结论，本包只负责把它翻成一行字。');
    }

    buffer
      ..writeln()
      ..writeln('— 4. 宿主自己贴一条：post 不抛异常，只回答有没有出去 —');
    final posted = await MediaCoreNotify.post(
      const NotifyEvent(
        title: '演示：手动通知',
        body: '宿主自己调用 MediaCoreNotify.post 的一条',
      ),
    );
    buffer
      ..writeln('post -> $posted（false 表示这个平台没把它送出去，而不是抛了异常）')
      ..writeln()
      ..writeln('— 5. 全部释放，线随之消失 —');
    await recording.lease.release();
    await _settle();
    _writeLines(buffer, '都停了');

    return buffer.toString();
  }

  void _writeLines(StringBuffer buffer, String caption) {
    buffer
      ..writeln('（$caption）drawsLine = ${ForegroundJobs.drawsLine}'
          ' —— Android 由每个功能自己的前台服务画，这里为 false')
      ..writeln('  线总数 runningCount = ${ForegroundJobs.runningCount}');

    for (final owner in BackgroundServiceOwner.jobOwners) {
      final title = ForegroundJobs.titleFor(owner);
      final body = ForegroundJobs.bodyFor(owner);
      final shown = ForegroundJobs.isShowingLineFor(owner);
      buffer.writeln(
        '  ${owner.name}: ${title ?? '没人'}'
        '${body == null ? '' : ' / $body'}'
        '  (持有会话 ${ForegroundJobs.sessionsFor(owner).length} 个, 线上=${shown ? '有' : '无'})',
      );
    }
  }

  Future<void> _settle() => Future<void>.delayed(Duration.zero);
}
