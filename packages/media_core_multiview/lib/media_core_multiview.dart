/// Multi-cell live wall for media_core.
///
/// N independent live cells in one grid, with the properties a monitoring wall
/// needs: per-cell health, exactly one audio owner, a decode budget that the
/// wall respects, per-cell danmaku and a patrol that rotates the focus.
///
/// ```dart
/// final wall = MultiviewController(
///   players: KernelPoolPlayerHost(kernel),
///   config: MultiviewConfig.defaults.copyWith(layout: MultiviewLayout.quad),
/// );
/// await wall.assignAll(sources);
/// await wall.setAudioFocus(2);
/// await wall.handOverCell(2, (playerId) => pipSession.enter(PlayerId(playerId)));
/// ```
///
/// The wall owns players through the core's [PoolPlayerHost], so a cell that is
/// switched to another room reuses a warm player instead of paying for a cold
/// one; it renders nothing, resolves nothing and owns no window.
library;

export 'src/multiview_cell.dart';
export 'src/multiview_config.dart';
export 'src/multiview_controller.dart';
export 'src/multiview_layout.dart';
