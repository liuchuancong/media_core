/// Adapter error categories.
enum PlayerAdapterErrorType {
  /// Unknown failure.
  unknown,

  /// Source cannot be opened.
  openFailed,

  /// Network connection failed.
  network,

  /// Unsupported media format.
  unsupportedFormat,

  /// Decoder initialization failed.
  decoder,

  /// Hardware acceleration failure.
  hardwareDecoder,

  /// Audio output failure.
  audio,

  /// Renderer failure.
  renderer,

  /// Invalid operation.
  invalidOperation,

  /// Backend internal failure.
  backend,
}
