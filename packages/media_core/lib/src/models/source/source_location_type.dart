/// Where a media source is reached from.
///
/// The category a source location is filed under, and the field that
/// actually carries its address.
enum SourceLocationType {
  /// Unknown location.
  unknown,

  /// Network resource.
  network,

  /// Local file.
  file,

  /// Application asset.
  asset,

  /// Custom location.
  custom,
}
