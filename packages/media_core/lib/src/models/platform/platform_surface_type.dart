/// Surface kinds a platform can present video through.
enum PlatformSurfaceType {
  /// Flutter texture based output.
  ///
  /// Example:
  ///
  /// - media_kit_video
  /// - Texture widget
  texture,

  /// Native surface output.
  ///
  /// Example:
  ///
  /// - Android SurfaceTexture
  /// - MediaCodec Surface
  surface,

  /// Window/native handle output.
  ///
  /// Example:
  ///
  /// - desktop overlay
  window,

  /// Software frame output.
  frame,

  /// Unknown surface.
  unknown,
}
