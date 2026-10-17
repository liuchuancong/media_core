import 'package:example/demos/fakes/fake_pool_player.dart';
import 'package:example/demos/module_demo.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_feed/media_core_feed.dart' show FeedConfig;
import 'package:media_core_list_playback/media_core_list_playback.dart' show PlaybackListConfig;
import 'package:media_core_live/media_core_live.dart' show LivePoolPolicy;

/// The player pool: which item plays, which ones stay warm, what gets recycled.
///
/// This is the least visible module in the framework — a viewer sees the right
/// item play, not a pool — and it is the one that decides how many decoders
/// exist at once. A console trace is the medium that fits: every line below is
/// one reconciliation, printed with the plan it produced.
class PoolDemo extends ModuleDemo {
  /// Creates the demo.
  const new();

  @override
  String get id => 'pool';

  @override
  ModuleCategory get category => ModuleCategory.playbackChain;

  @override
  String get nameZh => '播放器池：可见性驱动的复用';

  @override
  String get nameEn => 'PlayerIdentity pool: visibility-driven reuse';

  @override
  String get purposeZh =>
      '池按"哪一项被看得最多"决定谁在播，用滞回避免滚动时反复起停，用暖窗把相邻项保持打开，靠重新指向空闲播放器而不是新建解码器；压力来了先砍暖窗。反馈顺序用 SerialExecutor 串行化，所以计划永远是完整的。';

  @override
  String get purposeEn =>
      'The pool picks the item with the most visible area, uses hysteresis so scrolling does not stop and start playback, keeps neighbours open in a warm window, and re-points an idle player instead of creating a decoder. Pressure shrinks the warm window first. Reconciliations are serialized through SerialExecutor, so every plan is a complete one.';

  @override
  List<String> get pointsZh => const <String>[
    'setItems / onVisibilityChanged(ratio) — 池的输入只有"哪一项露出多少"',
    'playVisibilityThreshold 明确可见即接管；否则 pauseVisibilityThreshold 之上保持当前项（滞回）',
    '暖窗 preloadCount 把相邻项打开但不播，滑动到位时是换源而不是冷启动',
    'reuseIdlePlayers — 空闲播放器被重新指向，而不是新建（看 host 的 created 计数）',
    'reportPressure(emergency) — 预载降为 0，暖窗收缩，超出窗口的空闲项被释放',
    'setViewportVisible(false) / setOccluded(true) — 整页离开或应用退后台时，只剩账本',
    '第 7 段真跑一遍三个功能自己的预设（feed / list / live）：预设不是文档里的数字，而是池实际的窗口形状 —— 也因此在跑之前没人发现 `warmSize` 有两种读法',
  ];

  @override
  List<String> get pointsEn => const <String>[
    "setItems / onVisibilityChanged(ratio) — the pool's only input is how much of an item is visible",
    'playVisibilityThreshold takes over when something is clearly visible; otherwise the current item is kept above pauseVisibilityThreshold (hysteresis)',
    'The warm window (preloadCount) opens neighbours without playing them, so a swipe is a source swap, not a cold start',
    "reuseIdlePlayers re-points an idle player instead of creating one (watch the host's created count)",
    'reportPressure(emergency) drops preload to zero, shrinks the window and releases idle players outside it',
    'setViewportVisible(false) / setOccluded(true) — the page or the app went away; only the ledger is left',
    'Section 7 runs each feature’s own preset (feed / list / live): a preset is only real if the pool acts on it, and running it is how a number with two meanings shows up',
  ];

  @override
  String get snippet => '''
final pool = PlaybackPoolOrchestrator(host: myHost, config: const PlayerPoolConfig(
  preloadCount: 1, warmSize: 3, reuseIdlePlayers: true, maxPlayers: 6,
));
await pool.setItems(sources);

// The scroll view reports what it sees; the pool decides what plays.
await pool.onVisibilityChanged(3, 0.92);   // a swipe settled
await pool.onVisibilityChanged(3, 0.40);   // mid-scroll: keep it playing

if (pool.handleFor(3) != null) {
  MediaPlayerView(handle: (pool.handleFor(3)! as KernelPoolPlayerHandle).handle);
}
''';

  /// What a pool config says, in the numbers a reader is comparing.
  String _describe(PlayerPoolConfig config) {
    return 'warmSize=${config.warmSize}  preloadCount=${config.preloadCount}  '
        'idle=${config.idleTimeout?.inSeconds ?? '-'}s  keepWarm=${config.keepWarm}  '
        'max=${config.maxPlayers == 0 ? 'unlimited' : '${config.maxPlayers}'}';
  }

  List<PlayerSource> _sources() {
    return <PlayerSource>[
      for (var index = 0; index < 8; index++)
        PlayerSource(
          id: SourceId('room-$index'),
          uri: Uri.parse('https://example.com/live/$index.m3u8'),
          type: SourceType.remote,
          mediaType: SourceMediaType.video,
          title: 'room $index',
        ),
    ];
  }

  @override
  Future<String> run() async {
    final buffer = StringBuffer();

    final host = FakePoolPlayerHost();
    const walkConfig = PlayerPoolConfig(warmSize: 3, maxPlayers: 6);
    final pool = PlaybackPoolOrchestrator(host: host, config: walkConfig);

    try {
      await pool.setItems(_sources());
      buffer
        ..writeln('8 items, ${_describe(walkConfig)}')
        ..writeln();

      Future<void> show(String label, PlaybackPoolPlan plan) async {
        final roles = <String>[
          for (final item in plan.items)
            if (item.role != PooledItemRole.released) '#${item.index}:${item.role.name}',
        ];
        buffer
          ..writeln(label)
          ..writeln(
            '  active=${plan.activeIndex}  held=${plan.heldCount}  '
            'players created=${host.handles.length}  acquired=${host.acquires}',
          )
          ..writeln('  ${roles.isEmpty ? '(nothing held)' : roles.join('  ')}');
      }

      // A page settles on item 3.
      await show('scroll settles on item 3 (92% visible)', await pool.onVisibilityChanged(3, 0.92));

      // Mid-scroll: item 3 is half off screen, item 4 is barely peeking in.
      await pool.onVisibilityChanged(3, 0.6);
      await show(
        'mid-scroll: item 4 peeks in (35%), item 3 still 60% visible',
        await pool.onVisibilityChanged(4, 0.35),
      );
      buffer
        ..writeln('  → unchanged: nothing is *clearly* visible (35% is below the takeover')
        ..writeln('    threshold), so the item that is still over half visible keeps playing.');

      // The swipe completes.
      await show('swipe completes: item 4 at 95%', await pool.onVisibilityChanged(4, 0.95));

      // Back up. A scroll view reports every item it shows, so item 4's ratio
      // has to fall as item 3's rises — otherwise the pool still believes item 4
      // is the more visible one, and rightly keeps it.
      await pool.onVisibilityChanged(4, 0.1);
      await show('scroll back up to item 3 (its neighbours are already open)', await pool.onVisibilityChanged(3, 0.9));

      buffer
        ..writeln()
        ..writeln(
          '  → six visibility reports (two of them mid-scroll), and only '
          '${host.handles.length} player(s) ever existed:',
        )
        ..writeln('    ${host.summary()}')
        ..writeln('    the item the swipe reached was already open, so it was re-pointed, not created.')
        ..writeln();

      // Pressure: the warm window is the first thing to give up.
      await show('device reports critical pressure', await pool.reportPressure(ResourcePressure.critical));

      await show('device reports emergency pressure', await pool.reportPressure(ResourcePressure.emergency));

      buffer
        ..writeln()
        ..writeln('  → warming is what a device in trouble gives up first: it costs a decoder')
        ..writeln('    for something the viewer has not asked for yet.')
        ..writeln();

      await show('pressure clears', await pool.reportPressure(ResourcePressure.none));
      buffer
        ..writeln()
        ..writeln('  → ${host.summary()}: releasing under pressure is a teardown, not a pause,')
        ..writeln('    so coming back from it costs fresh players. That is the trade the')
        ..writeln('    budget policy makes when it gives the warm window up first.');

      // Leaving the page: nothing may keep playing.
      await show('the list scrolled fully out of view', await pool.setViewportVisible(visible: false));

      buffer
        ..writeln()
        ..writeln('  → a pool that keeps playing for an invisible page is a battery bug;')
        ..writeln('    setOccluded(true) is the same decision for "the app went to background".')
        // The feature presets, run rather than quoted.
        //
        // Each capability package ships the window shape it wants and hands it to
        // the host — and until this section none of them was ever built anywhere,
        // so "live keeps one spare and lets go after 15s" was a sentence about a
        // preset nobody had watched the pool act on.
        ..writeln()
        ..writeln('— 7. 功能预设：同一台池，各家的窗口 —')
        ..writeln('  同一步"落在第 3 项"，分别用每个功能推荐的预设跑一遍，看池真的留了什么在册：');

      for (final preset in <({String name, PlayerPoolConfig config})>[
        (name: 'feed', config: FeedConfig.recommendedPoolConfig),
        (name: 'list', config: PlaybackListConfig.recommendedPoolConfig),
        (name: 'live', config: LivePoolPolicy.defaults.toPoolConfig()),
      ]) {
        final presetHost = FakePoolPlayerHost();
        final presetPool = PlaybackPoolOrchestrator(host: presetHost, config: preset.config);

        try {
          await presetPool.setItems(_sources());
          final plan = await presetPool.onVisibilityChanged(3, 0.92);
          final roles = <String>[
            for (final item in plan.items)
              if (item.role != PooledItemRole.released) '#${item.index}:${item.role.name}',
          ];

          buffer.writeln(
            '  ${preset.name.padRight(5)} ${_describe(preset.config)}  '
            '→ held=${plan.heldCount}  ${roles.isEmpty ? '(nothing held)' : roles.join('  ')}',
          );
        } finally {
          await presetPool.dispose();
          await presetHost.disposeAll();
        }
      }

      buffer
        ..writeln('  → 差别只在 idle：直播 15 秒放手，列表与刷流 30 秒。直播没有"下一条"，暖着的是备用线路，开着不放等于替没人看的流付带宽。')
        ..writeln('  ⚠ 而 `LivePoolPolicy` 自己写着"只留一份备用"，这一跑却留了两份（#2 与 #4）。原因不在预设，在 `warmSize`：池里一处把它读成"暖着的播放器数"，另一处读成"在册总数"，同一个数字两种口径，预设的算术与它的文档就只能有一边是真的。');

      // What the memory module sees from this pool.
      final account = MediaCoreMemory.report().forModule(MemoryModule.pool);
      buffer
        ..writeln()
        ..writeln(
          'memory module view of the same pool: ${account?.bytes ?? 0} bytes declared, '
          '${account?.items ?? 0} item(s) — "${account?.note}"',
        );

      return buffer.toString();
    } finally {
      await pool.dispose();
      await host.disposeAll();
    }
  }
}
