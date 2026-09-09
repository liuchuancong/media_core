/// Defines player presentation policies.
///
/// [PresentationPolicy] controls how the player
/// can be presented on different platforms.
///
/// Responsibilities:
///
/// - fullscreen permission
/// - picture-in-picture permission
/// - floating window permission
/// - orientation behavior
/// - system UI behavior
///
/// It does not:
///
/// - enter fullscreen
/// - create PiP window
/// - manage overlays
///
/// Those belong to:
///
/// - PresentationController
/// - FullscreenController
/// - PipController
final class PresentationPolicy {
  /// Creates presentation policy.
  const PresentationPolicy({
    this.enabled = true,

    this.allowFullscreen = true,

    this.allowPictureInPicture = true,

    this.allowFloatingWindow = true,

    this.autoFullscreenOnLandscape = false,

    this.autoExitFullscreenOnPortrait = false,

    this.lockOrientationInFullscreen = true,

    this.hideSystemUiInFullscreen = true,

    this.restoreSystemUiAfterExit = true,
  });

  /// Whether presentation management is enabled.
  final bool enabled;

  /// Allow fullscreen mode.
  final bool allowFullscreen;

  /// Allow picture-in-picture mode.
  final bool allowPictureInPicture;

  /// Allow floating player window.
  final bool allowFloatingWindow;

  /// Automatically enter fullscreen when
  /// device rotates landscape.
  final bool autoFullscreenOnLandscape;

  /// Automatically exit fullscreen when
  /// device rotates portrait.
  final bool autoExitFullscreenOnPortrait;

  /// Lock orientation while fullscreen.
  final bool lockOrientationInFullscreen;

  /// Hide system UI in fullscreen.
  final bool hideSystemUiInFullscreen;

  /// Restore system UI after exiting.
  final bool restoreSystemUiAfterExit;

  /// Whether fullscreen is available.
  bool canFullscreen() {
    return enabled && allowFullscreen;
  }

  /// Whether PiP is available.
  bool canPictureInPicture() {
    return enabled && allowPictureInPicture;
  }

  /// Whether floating mode is available.
  bool canFloating() {
    return enabled && allowFloatingWindow;
  }

  /// Whether orientation should lock.
  bool shouldLockOrientation() {
    return enabled && lockOrientationInFullscreen;
  }

  /// Whether system UI should hide.
  bool shouldHideSystemUi() {
    return enabled && hideSystemUiInFullscreen;
  }

  /// Creates modified policy.
  PresentationPolicy copyWith({
    bool? enabled,

    bool? allowFullscreen,

    bool? allowPictureInPicture,

    bool? allowFloatingWindow,

    bool? autoFullscreenOnLandscape,

    bool? autoExitFullscreenOnPortrait,

    bool? lockOrientationInFullscreen,

    bool? hideSystemUiInFullscreen,

    bool? restoreSystemUiAfterExit,
  }) {
    return PresentationPolicy(
      enabled: enabled ?? this.enabled,

      allowFullscreen: allowFullscreen ?? this.allowFullscreen,

      allowPictureInPicture: allowPictureInPicture ?? this.allowPictureInPicture,

      allowFloatingWindow: allowFloatingWindow ?? this.allowFloatingWindow,

      autoFullscreenOnLandscape: autoFullscreenOnLandscape ?? this.autoFullscreenOnLandscape,

      autoExitFullscreenOnPortrait: autoExitFullscreenOnPortrait ?? this.autoExitFullscreenOnPortrait,

      lockOrientationInFullscreen: lockOrientationInFullscreen ?? this.lockOrientationInFullscreen,

      hideSystemUiInFullscreen: hideSystemUiInFullscreen ?? this.hideSystemUiInFullscreen,

      restoreSystemUiAfterExit: restoreSystemUiAfterExit ?? this.restoreSystemUiAfterExit,
    );
  }

  @override
  String toString() {
    return 'PresentationPolicy('
        'fullscreen=$allowFullscreen, '
        'pip=$allowPictureInPicture, '
        'floating=$allowFloatingWindow'
        ')';
  }
}
