import 'package:example/demos/module_demo.dart';
import 'package:media_core_mediasession/media_core_mediasession.dart';

/// Who owns the platform's media control bar, and what a stale writer cannot do.
///
/// The kernel path (`setActive(handle)`) is what usually claims the surface. This
/// demo walks the *named session* path a host uses when it has no handle to bind —
/// a wall that wants one cell to own the lock screen, a player that is being handed
/// over — because that is the path whose rules are invisible until something goes
/// wrong: a claim reports who it displaced, a write from a session that no longer
/// owns the bar is dropped, and a give-up by a non-owner gives up nothing.
class MediaSessionOwnershipDemo extends ModuleDemo {
  /// Creates the demo.
  const new();

  @override
  String get id => 'media-session-ownership';

  @override
  ModuleCategory get category => ModuleCategory.capability;

  @override
  String get nameZh => '媒体面所有权（宿主接管 / 陈旧写入 / 交还）';

  @override
  String get nameEn => 'Media surface ownership (claim, stale write, hand back)';

  @override
  String get purposeZh =>
      '平台只有一条媒体通知，所以"谁在上面"必须有唯一答案。这段演示用命名会话接管它、'
      '让上一个主人迟到地改写和收走（都应当无效）、再原样交还，把三条所有权规则一次跑给你看。'
      '媒体面没启用时它直接回答 notEnabled —— 不是一个会被忽略的 null。';

  @override
  String get purposeEn =>
      'One platform media notification, so "who is showing" needs one answer. This claims it with a named '
      'session, lets the previous owner try to rewrite and clear it late (both must be ignored), and hands it '
      'back. With no surfaces enabled it answers notEnabled rather than returning a null a host would ignore.';

  @override
  String get snippet => r'''
final claim = await MediaSessionSurfaces.activate(sessionId: 'wall/cell-2', title: '房间 42');
if (!claim.held) return;                       // notEnabled / notInitialized / surfaceUnavailable / disposed
print('接管自：${claim.previousOwnerSessionId}');   // the loser cannot see its own loss

await MediaSessionSurfaces.deactivate('wall/cell-1');  // a stale owner gives up nothing
await MediaSessionSurfaces.deactivate('wall/cell-2');  // the owner gives the bar back
''';

  @override
  List<String> get pointsZh => const <String>[
    'MediaSessionSurfaces 是给"没有 PlayerHandle 可绑"的宿主用的门：activate / updateMetadata / deactivate / activeSessionId',
    '接管结果会说出它从谁手里拿走的面（previousOwnerSessionId）——被挤掉的那一方从自己这边是看不见自己输了',
    '不是主人就改写不了那一格，也收不走别人的通知；多画面切换里旧玩家的迟到回调正是靠这条被丢弃',
    '媒体面没启用时 activate 答 notEnabled，而不是回一个可以被忽略的 null：把"没启用"读成"接管成功"就是文档 §9.3 要消掉的那个假后台播放',
    '四个拒绝各有各的动作：notEnabled（先 enable）、notInitialized（等握手）、surfaceUnavailable（这平台就没有）、disposed（还在调用已扔掉的驱动）',
    '这条面属于播放：audio_service 的服务与通知（宿主的清单要声明）；录制与下载那条是 media_core_native 每功能一个服务，互不覆盖',
  ];

  @override
  List<String> get pointsEn => const <String>[
    'MediaSessionSurfaces is the door for a host with no PlayerHandle to bind: activate / updateMetadata / deactivate / activeSessionId',
    'A claim names the session it displaced, because the loser cannot see its own loss from its side',
    'A session that no longer owns the bar can neither rewrite it nor clear it — the multiview callback bug, made impossible',
    'With no surfaces enabled, activate answers notEnabled instead of returning a null a host ignores: reading "nothing happened" as "claimed" is the fake background playback §9.3 set out to remove',
    'Each refusal asks for a different action: notEnabled (enable first), notInitialized (wait), surfaceUnavailable (this platform has none), disposed (still calling a thrown-away driver)',
    'This surface belongs to playback (audio_service, declared by the host manifest); recording and download are media_core_native per-feature services that never overwrite it',
  ];

  @override
  Future<String> run() async {
    final buffer = StringBuffer()
      ..writeln('MediaSessionBootstrap.enabled: ${MediaSessionBootstrap.enabled}')
      ..writeln();

    if (!MediaSessionBootstrap.enabled) {
      final activation = await MediaSessionSurfaces.activate(sessionId: 'demo/claim', title: '演示：宿主接管');

      buffer
        ..writeln('— 媒体面没启用：接管被拒，并且说清了为什么 —')
        ..writeln('activate -> ${activation.reason?.name}')
        ..writeln(
          'A host reading `MediaSessionBootstrap.current == null` would have to notice the difference itself; '
          'this is the same door, refusing out loud.',
        )
        ..writeln('当前主人：${MediaSessionSurfaces.activeSessionId ?? '没人'}');

      return buffer.toString();
    }

    final previous = MediaSessionSurfaces.activeSessionId;
    buffer.writeln('开始时持有媒体面的会话：${previous ?? '没人（还没有播放器绑上来）'}');

    final claim = await MediaSessionSurfaces.activate(sessionId: 'demo/claim', title: '演示：宿主接管');

    buffer
      ..writeln()
      ..writeln('— 1. 以命名会话接管 / claim with a named session —')
      ..writeln('activate -> $claim')
      ..writeln('现在 activeSessionId = ${MediaSessionSurfaces.activeSessionId}');

    if (!claim.held) {
      buffer
        ..writeln(
          '平台没有媒体面可给（web 或桌面没有 SMTC/MPRIS，或握手还没跑完），所以这条通知根本不存在 —— '
          '而不是"看起来接管成功了"。',
        )
        ..writeln('The platform had no surface to hand over; the demo stops here rather than pretending.');

      return buffer.toString();
    }

    if (previous != null) {
      buffer
        ..writeln()
        ..writeln('— 2. 被挤掉的那一方能不能自己收走？/ can the displaced owner clear it? —')
        ..writeln('deactivate("$previous")  // 它已经不是主人了')
        ..writeln('   → activeSessionId = ${await _deactivateAndRead(previous)}')
        ..writeln('   答案还是 demo/claim：收走别人的通知不是它的权利。');
    }

    buffer
      ..writeln()
      ..writeln('— 3. 迟到的改写会不会覆盖现在那一格？/ does a stale rewrite land? —');
    await MediaSessionSurfaces.updateMetadata(
      sessionId: previous ?? 'demo/nobody',
      title: '旧会话的迟到回调',
    );
    buffer
      ..writeln('updateMetadata("${previous ?? 'demo/nobody'}", "旧会话的迟到回调")')
      ..writeln('   → activeSessionId = ${MediaSessionSurfaces.activeSessionId}（多画面切换里这就是那个 bug 的形状）')
      ..writeln()
      ..writeln('— 4. 主人自己交还 / the owner gives it back —');
    await MediaSessionSurfaces.deactivate('demo/claim');
    await _settle();
    buffer.writeln('deactivate("demo/claim") → activeSessionId = ${MediaSessionSurfaces.activeSessionId}');

    if (previous != null) {
      final back = await MediaSessionSurfaces.activate(sessionId: previous, title: '还给 $previous');
      await _settle();
      buffer
        ..writeln('再交还给原来的会话：$back')
        ..writeln('   → activeSessionId = ${MediaSessionSurfaces.activeSessionId}');
    } else {
      buffer.writeln(
        '没有原主人可还：内核的活动播放器会在下一次绑定时（driver.setActive(handle)）重新发布，'
        '媒体面不会凭空留着一格没人认领。',
      );
    }

    return buffer.toString();
  }

  Future<String> _deactivateAndRead(String sessionId) async {
    await MediaSessionSurfaces.deactivate(sessionId);
    await _settle();

    return MediaSessionSurfaces.activeSessionId ?? '没人';
  }

  Future<void> _settle() => Future<void>.delayed(Duration.zero);
}
