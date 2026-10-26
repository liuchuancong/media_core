/// Renderer kinds a platform surface can present through.
enum PlatformRendererType {
  /// Flutter texture rendering.
  ///
  /// Used by:
  ///
  /// - media_kit_video
  /// - Texture widget
  texture,

  /// Native surface rendering.
  ///
  /// Used by:
  ///
  /// - Android Surface
  /// - hardware decoder output
  surface,

  /// Native overlay rendering.
  ///
  /// Used by:
  ///
  /// - desktop video overlay
  overlay,

  /// Software frame rendering.
  ///
  /// Used when GPU is unavailable.
  software,

  /// Unknown renderer.
  unknown,
}
