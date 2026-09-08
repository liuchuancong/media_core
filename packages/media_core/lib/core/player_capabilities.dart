import 'package:equatable/equatable.dart';

/// Describes the capabilities supported by a player.
///
/// [PlayerCapabilities] is a declarative model used by higher-level
/// components to determine which player operations and presentation
/// features are available.
///
/// Capabilities describe what a player can do, not what it is currently
/// doing. Runtime state belongs to [PlayerState].
final class PlayerCapabilities extends Equatable {
  /// Creates a player capabilities model.
  const PlayerCapabilities({
    this.canInitialize = true,
    this.canOpen = true,
    this.canPlay = true,
    this.canPause = true,
    this.canStop = true,
    this.canSeek = true,
    this.canSetVolume = true,
    this.canSetPlaybackRate = true,
    this.canMute = true,
    this.canFullscreen = false,
    this.canPip = false,
    this.canFloating = false,
    this.canRecord = false,
    this.canChangeSource = true,
    this.canSelectQuality = false,
    this.canSelectLine = false,
    this.canRecover = true,
    this.canFallback = true,
  });

  /// Whether the player supports initialization.
  final bool canInitialize;

  /// Whether the player supports opening a source.
  final bool canOpen;

  /// Whether the player supports starting playback.
  final bool canPlay;

  /// Whether the player supports pausing playback.
  final bool canPause;

  /// Whether the player supports stopping playback.
  final bool canStop;

  /// Whether the player supports seeking.
  final bool canSeek;

  /// Whether the player supports volume changes.
  final bool canSetVolume;

  /// Whether the player supports playback-rate changes.
  final bool canSetPlaybackRate;

  /// Whether the player supports muting and unmuting.
  final bool canMute;

  /// Whether the player supports fullscreen presentation.
  final bool canFullscreen;

  /// Whether the player supports picture-in-picture presentation.
  final bool canPip;

  /// Whether the player supports floating presentation.
  final bool canFloating;

  /// Whether the player supports recording.
  final bool canRecord;

  /// Whether the player supports changing the current source.
  final bool canChangeSource;

  /// Whether the player supports quality selection.
  final bool canSelectQuality;

  /// Whether the player supports line or stream selection.
  final bool canSelectLine;

  /// Whether the player supports recovery after a failure.
  final bool canRecover;

  /// Whether the player supports backend or source fallback.
  final bool canFallback;

  /// Returns whether the player provides basic playback controls.
  bool get hasPlaybackControls {
    return canPlay || canPause || canStop || canSeek;
  }

  /// Returns whether the player provides presentation features.
  bool get hasPresentationFeatures {
    return canFullscreen || canPip || canFloating;
  }

  /// Returns whether the player provides source-selection features.
  bool get hasSourceSelection {
    return canChangeSource || canSelectQuality || canSelectLine;
  }

  /// Returns whether the player supports recording.
  bool get hasRecording => canRecord;

  /// Returns whether the player supports failure recovery.
  bool get hasRecovery => canRecover || canFallback;

  /// Returns whether only basic playback controls are available.
  bool get hasBasicPlaybackControls {
    return canPlay && canPause && canStop;
  }

  /// Returns whether advanced playback controls are available.
  bool get hasAdvancedPlaybackControls {
    return canSeek || canSetVolume || canSetPlaybackRate || canMute;
  }

  /// Returns whether the player has enough capabilities for basic playback.
  bool get canUsePlayback {
    return canInitialize && canOpen && canPlay;
  }

  /// Returns whether any presentation mode can be used.
  bool get canUsePresentation {
    return canFullscreen || canPip || canFloating;
  }

  /// Returns whether source selection can be used.
  bool get canUseSourceSelection {
    return canChangeSource || canSelectQuality || canSelectLine;
  }

  /// Creates a copy with selectively replaced capabilities.
  ///
  /// Null values retain the existing values.
  PlayerCapabilities copyWith({
    bool? canInitialize,
    bool? canOpen,
    bool? canPlay,
    bool? canPause,
    bool? canStop,
    bool? canSeek,
    bool? canSetVolume,
    bool? canSetPlaybackRate,
    bool? canMute,
    bool? canFullscreen,
    bool? canPip,
    bool? canFloating,
    bool? canRecord,
    bool? canChangeSource,
    bool? canSelectQuality,
    bool? canSelectLine,
    bool? canRecover,
    bool? canFallback,
  }) {
    return PlayerCapabilities(
      canInitialize: canInitialize ?? this.canInitialize,
      canOpen: canOpen ?? this.canOpen,
      canPlay: canPlay ?? this.canPlay,
      canPause: canPause ?? this.canPause,
      canStop: canStop ?? this.canStop,
      canSeek: canSeek ?? this.canSeek,
      canSetVolume: canSetVolume ?? this.canSetVolume,
      canSetPlaybackRate: canSetPlaybackRate ?? this.canSetPlaybackRate,
      canMute: canMute ?? this.canMute,
      canFullscreen: canFullscreen ?? this.canFullscreen,
      canPip: canPip ?? this.canPip,
      canFloating: canFloating ?? this.canFloating,
      canRecord: canRecord ?? this.canRecord,
      canChangeSource: canChangeSource ?? this.canChangeSource,
      canSelectQuality: canSelectQuality ?? this.canSelectQuality,
      canSelectLine: canSelectLine ?? this.canSelectLine,
      canRecover: canRecover ?? this.canRecover,
      canFallback: canFallback ?? this.canFallback,
    );
  }

  /// Returns capabilities with initialization disabled.
  PlayerCapabilities withoutInitialize() {
    return copyWith(canInitialize: false);
  }

  /// Returns capabilities with initialization enabled.
  PlayerCapabilities withInitialize() {
    return copyWith(canInitialize: true);
  }

  /// Returns capabilities with source opening disabled.
  PlayerCapabilities withoutOpen() {
    return copyWith(canOpen: false);
  }

  /// Returns capabilities with source opening enabled.
  PlayerCapabilities withOpen() {
    return copyWith(canOpen: true);
  }

  /// Returns capabilities with playback disabled.
  PlayerCapabilities withoutPlayback() {
    return copyWith(canPlay: false, canPause: false, canStop: false);
  }

  /// Returns capabilities with playback enabled.
  PlayerCapabilities withPlayback() {
    return copyWith(canPlay: true, canPause: true, canStop: true);
  }

  /// Returns capabilities with seeking disabled.
  PlayerCapabilities withoutSeek() {
    return copyWith(canSeek: false);
  }

  /// Returns capabilities with seeking enabled.
  PlayerCapabilities withSeek() {
    return copyWith(canSeek: true);
  }

  /// Returns capabilities without presentation features.
  PlayerCapabilities withoutPresentation() {
    return copyWith(canFullscreen: false, canPip: false, canFloating: false);
  }

  /// Returns capabilities with all presentation features enabled.
  PlayerCapabilities withPresentation() {
    return copyWith(canFullscreen: true, canPip: true, canFloating: true);
  }

  /// Returns capabilities without source-selection features.
  PlayerCapabilities withoutSourceSelection() {
    return copyWith(canChangeSource: false, canSelectQuality: false, canSelectLine: false);
  }

  /// Returns capabilities with source-selection features enabled.
  PlayerCapabilities withSourceSelection() {
    return copyWith(canChangeSource: true, canSelectQuality: true, canSelectLine: true);
  }

  /// Returns capabilities with recording disabled.
  PlayerCapabilities withoutRecording() {
    return copyWith(canRecord: false);
  }

  /// Returns capabilities with recording enabled.
  PlayerCapabilities withRecording() {
    return copyWith(canRecord: true);
  }

  /// Returns capabilities with recovery disabled.
  PlayerCapabilities withoutRecovery() {
    return copyWith(canRecover: false, canFallback: false);
  }

  /// Returns capabilities with recovery and fallback enabled.
  PlayerCapabilities withRecovery() {
    return copyWith(canRecover: true, canFallback: true);
  }

  /// Returns a minimal capability set.
  ///
  /// This preset is useful for players that only expose initialization,
  /// source opening, and basic playback.
  static const PlayerCapabilities minimal = PlayerCapabilities(
    canInitialize: true,
    canOpen: true,
    canPlay: true,
    canPause: true,
    canStop: true,
    canSeek: false,
    canSetVolume: true,
    canSetPlaybackRate: false,
    canMute: true,
    canFullscreen: false,
    canPip: false,
    canFloating: false,
    canRecord: false,
    canChangeSource: false,
    canSelectQuality: false,
    canSelectLine: false,
    canRecover: false,
    canFallback: false,
  );

  /// Returns the basic playback capability set.
  static const PlayerCapabilities basic = PlayerCapabilities();

  /// Returns a desktop-oriented capability set.
  static const PlayerCapabilities desktop = PlayerCapabilities(
    canFullscreen: true,
    canPip: true,
    canFloating: true,
    canRecord: true,
    canSelectQuality: true,
    canSelectLine: true,
  );

  /// Returns a TV-oriented capability set.
  static const PlayerCapabilities tv = PlayerCapabilities(
    canFullscreen: true,
    canPip: false,
    canFloating: false,
    canRecord: false,
    canSelectQuality: true,
    canSelectLine: true,
  );

  /// Returns whether two capability sets are equivalent.
  bool isSameAs(PlayerCapabilities other) {
    return this == other;
  }

  /// Returns whether two capability sets are different.
  bool isDifferentFrom(PlayerCapabilities other) {
    return this != other;
  }

  @override
  List<Object?> get props => <Object?>[
    canInitialize,
    canOpen,
    canPlay,
    canPause,
    canStop,
    canSeek,
    canSetVolume,
    canSetPlaybackRate,
    canMute,
    canFullscreen,
    canPip,
    canFloating,
    canRecord,
    canChangeSource,
    canSelectQuality,
    canSelectLine,
    canRecover,
    canFallback,
  ];

  @override
  String toString() {
    return 'PlayerCapabilities('
        'canInitialize: $canInitialize, '
        'canOpen: $canOpen, '
        'canPlay: $canPlay, '
        'canPause: $canPause, '
        'canStop: $canStop, '
        'canSeek: $canSeek, '
        'canSetVolume: $canSetVolume, '
        'canSetPlaybackRate: $canSetPlaybackRate, '
        'canMute: $canMute, '
        'canFullscreen: $canFullscreen, '
        'canPip: $canPip, '
        'canFloating: $canFloating, '
        'canRecord: $canRecord, '
        'canChangeSource: $canChangeSource, '
        'canSelectQuality: $canSelectQuality, '
        'canSelectLine: $canSelectLine, '
        'canRecover: $canRecover, '
        'canFallback: $canFallback'
        ')';
  }
}
