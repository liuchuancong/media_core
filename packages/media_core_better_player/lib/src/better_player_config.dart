import 'package:media_core/media_core.dart';
import 'package:better_player_plus/better_player_plus.dart';

/// Per-open hook that can rewrite the [BetterPlayerDataSource] built
/// from a [PlayerSource] (or the pre-bound [BetterPlayerConfig.dataSource]).
///
/// Runs last, just before `setupDataSource`, so it can override headers,
/// caching, DRM, resolver, etc.
typedef BetterPlayerDataSourceBuilder =
    BetterPlayerDataSource Function(PlayerSource source, BetterPlayerDataSource dataSource);

/// Configuration surface for [BetterPlayerAdapter].
///
/// This keeps BetterPlayer's own configuration objects intact instead
/// of duplicating their individual fields. The adapter passes these
/// objects through to BetterPlayerController/setupDataSource.
final class BetterPlayerConfig {
  const BetterPlayerConfig({this.configuration, this.playlistConfiguration, this.dataSource, this.configureDataSource});

  /// Base controller configuration passed to [BetterPlayerController].
  ///
  /// When null the adapter builds a minimal default (no controls,
  /// no lifecycle handling, no fullscreen-by-default, no looping).
  ///
  /// The adapter still owns two fields on top of this:
  ///
  /// - `autoPlay` is AND-ed with the audio-suppression state.
  /// - `fit` is driven by [BetterPlayerAdapter.setVideoFit].
  ///
  /// Everything else (subtitles, placeholder, overlay, cache, DRM,
  /// orientation, event listeners, translations, ...) passes through
  /// untouched.
  final BetterPlayerConfiguration? configuration;

  /// Playlist configuration passed as the
  /// `betterPlayerPlaylistConfiguration` named argument of
  /// [BetterPlayerController].
  final BetterPlayerPlaylistConfiguration? playlistConfiguration;

  /// Pre-bound data source passed to `setupDataSource`.
  ///
  /// When set, [BetterPlayerAdapter.onOpen] hands this source to
  /// `setupDataSource` instead of building one from [PlayerSource].
  ///
  /// This is the "fully own the source" escape hatch: cache, DRM,
  /// resolver, subtitles, video extension, etc.
  ///
  /// When null the adapter maps [PlayerSource] the usual way.
  final BetterPlayerDataSource? dataSource;

  /// Per-open rewrite applied on top of whichever source was selected
  /// above. Null keeps it as-is.
  final BetterPlayerDataSourceBuilder? configureDataSource;

  static const Object _noChange = Object();

  /// Creates a copy of this configuration.
  ///
  /// An omitted argument keeps its current value.
  ///
  /// Passing `null` explicitly clears the corresponding value.
  BetterPlayerConfig copyWith({
    Object? configuration = _noChange,
    Object? playlistConfiguration = _noChange,
    Object? dataSource = _noChange,
    Object? configureDataSource = _noChange,
  }) {
    return BetterPlayerConfig(
      configuration: identical(configuration, _noChange)
          ? this.configuration
          : configuration as BetterPlayerConfiguration?,
      playlistConfiguration: identical(playlistConfiguration, _noChange)
          ? this.playlistConfiguration
          : playlistConfiguration as BetterPlayerPlaylistConfiguration?,
      dataSource: identical(dataSource, _noChange) ? this.dataSource : dataSource as BetterPlayerDataSource?,
      configureDataSource: identical(configureDataSource, _noChange)
          ? this.configureDataSource
          : configureDataSource as BetterPlayerDataSourceBuilder?,
    );
  }
}
