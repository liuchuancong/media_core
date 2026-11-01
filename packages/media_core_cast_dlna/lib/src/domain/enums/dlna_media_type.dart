/// The kind of content a media item carries.
enum DlnaMediaType {
  /// A video item (`object.item.videoItem`).
  video,

  /// An audio item (`object.item.audioItem`).
  audio,

  /// An image item (`object.item.imageItem`).
  image,

  /// Anything the package cannot classify.
  unknown;

  /// Classifies a MIME type; unknown MIMEs stay [unknown] — the caller
  /// may still know better from the object class.
  static DlnaMediaType fromMimeType(String? mimeType) {
    final value = mimeType?.toLowerCase();
    if (value == null) {
      return unknown;
    }
    if (value.startsWith('video/')) {
      return video;
    }
    if (value.startsWith('audio/')) {
      return audio;
    }
    if (value.startsWith('image/')) {
      return image;
    }
    return unknown;
  }

  /// The DIDL-Lite object class suffix (`videoItem`, ...).
  String get objectClassName => switch (this) {
    video => 'videoItem',
    audio => 'audioItem',
    image => 'imageItem',
    unknown => 'item',
  };
}
