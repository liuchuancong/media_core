import 'page_coordinator.dart';
import 'audio_coordinator.dart';
import 'preload_coordinator.dart';
import 'playback_coordinator.dart';
import 'resource_coordinator.dart';
import 'lifecycle_coordinator.dart';
import 'presentation_coordinator.dart';

/// Global coordinator for player runtime.
///
/// [GlobalPlayerCoordinator] is the root
/// coordination layer.
///
/// It combines all player related
/// coordinators.
///
/// It does not:
///
/// - create players
/// - execute backend commands
/// - store playback state
///
/// Those belong to:
///
/// - PlayerFactory
/// - PlayerAdapter
/// - PlaybackController
final class GlobalPlayerCoordinator {
  /// Creates global coordinator.
  GlobalPlayerCoordinator({
    PlaybackCoordinator? playback,
    PageCoordinator? page,
    AudioCoordinator? audio,
    ResourceCoordinator? resource,
    PreloadCoordinator? preload,
    LifecycleCoordinator? lifecycle,
    PresentationCoordinator? presentation,
  }) : playback = playback ?? PlaybackCoordinator(),
       page = page ?? PageCoordinator(),
       audio = audio ?? AudioCoordinator(),
       resource = resource ?? ResourceCoordinator(),
       preload = preload ?? PreloadCoordinator(),
       lifecycle = lifecycle ?? LifecycleCoordinator(),
       presentation = presentation ?? PresentationCoordinator();

  /// Playback coordination.
  final PlaybackCoordinator playback;

  /// Page coordination.
  final PageCoordinator page;

  /// Audio coordination.
  final AudioCoordinator audio;

  /// Resource coordination.
  final ResourceCoordinator resource;

  /// Preload coordination.
  final PreloadCoordinator preload;

  /// Lifecycle coordination.
  final LifecycleCoordinator lifecycle;

  /// Presentation coordination.
  final PresentationCoordinator presentation;

  /// Initializes coordinator.
  Future<void> initialize() async {}

  /// Clears all runtime bindings.
  void clear() {
    playback.clear();

    page.clear();

    audio.clear();

    resource.clear();

    preload.clear();

    lifecycle.clear();

    presentation.clear();
  }

  /// Disposes all coordinators.
  Future<void> dispose() async {
    await playback.dispose();

    await page.dispose();

    await audio.dispose();

    await resource.dispose();

    await preload.dispose();

    await lifecycle.dispose();

    await presentation.dispose();
  }
}
