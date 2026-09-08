import 'package:equatable/equatable.dart';

/// Represents immutable runtime metrics collected from a player.
///
/// [PlayerMetrics] contains lightweight playback, buffering, rendering,
/// and resource-related measurements. It is intended for diagnostics,
/// monitoring, and performance analysis rather than player state control.
final class PlayerMetrics extends Equatable {
  /// Creates immutable player metrics.
  const PlayerMetrics({
    this.position,
    this.duration,
    this.bufferedPosition,
    this.bufferingDuration,
    this.playbackRate = 1.0,
    this.volume = 1.0,
    this.videoWidth,
    this.videoHeight,
    this.droppedFrames = 0,
    this.renderedFrames = 0,
    this.decodedFrames = 0,
    this.bufferCount = 0,
    this.errorCount = 0,
    this.recoveryCount = 0,
    this.fallbackCount = 0,
    this.networkBytesReceived = 0,
    this.networkBytesSent = 0,
    this.createdAt,
    this.updatedAt,
    this.metadata = const <String, Object?>{},
  }) : assert(playbackRate > 0.0),
       assert(volume >= 0.0 && volume <= 1.0),
       assert(droppedFrames >= 0),
       assert(renderedFrames >= 0),
       assert(decodedFrames >= 0),
       assert(bufferCount >= 0),
       assert(errorCount >= 0),
       assert(recoveryCount >= 0),
       assert(fallbackCount >= 0),
       assert(networkBytesReceived >= 0),
       assert(networkBytesSent >= 0);

  /// Current playback position.
  final Duration? position;

  /// Total media duration.
  ///
  /// This is null for streams where the duration is unknown.
  final Duration? duration;

  /// Current buffered media position.
  final Duration? bufferedPosition;

  /// Total accumulated buffering duration.
  final Duration? bufferingDuration;

  /// Current playback rate.
  final double playbackRate;

  /// Current player volume.
  ///
  /// The value is normalized to the range 0.0 to 1.0.
  final double volume;

  /// Current video width in pixels.
  final int? videoWidth;

  /// Current video height in pixels.
  final int? videoHeight;

  /// Number of frames dropped during playback.
  final int droppedFrames;

  /// Number of frames rendered during playback.
  final int renderedFrames;

  /// Number of frames decoded during playback.
  final int decodedFrames;

  /// Number of buffering events.
  final int bufferCount;

  /// Number of errors observed by the player.
  final int errorCount;

  /// Number of recovery attempts or executions.
  final int recoveryCount;

  /// Number of fallback attempts or executions.
  final int fallbackCount;

  /// Total number of bytes received by the player.
  final int networkBytesReceived;

  /// Total number of bytes sent by the player.
  final int networkBytesSent;

  /// Time when these metrics were created.
  final DateTime? createdAt;

  /// Time when these metrics were last updated.
  final DateTime? updatedAt;

  /// Additional metric metadata.
  final Map<String, Object?> metadata;

  /// Returns whether a playback position is available.
  bool get hasPosition => position != null;

  /// Returns whether a duration is available.
  bool get hasDuration => duration != null;

  /// Returns whether buffered position is available.
  bool get hasBufferedPosition => bufferedPosition != null;

  /// Returns whether buffering duration is available.
  bool get hasBufferingDuration => bufferingDuration != null;

  /// Returns whether video dimensions are available.
  bool get hasVideoDimensions => videoWidth != null && videoHeight != null;

  /// Returns whether the media has finite duration information.
  bool get hasFiniteDuration {
    return duration != null && duration! > Duration.zero;
  }

  /// Returns whether the media appears to be live.
  bool get isLive {
    return duration == null;
  }

  /// Returns whether playback is behind the buffered position.
  bool get isBufferedAhead {
    if (position == null || bufferedPosition == null) {
      return false;
    }

    return bufferedPosition! > position!;
  }

  /// Returns the amount of media currently buffered ahead.
  Duration? get bufferAhead {
    if (position == null || bufferedPosition == null) {
      return null;
    }

    final difference = bufferedPosition! - position!;

    if (difference.isNegative) {
      return Duration.zero;
    }

    return difference;
  }

  /// Returns the video aspect ratio when dimensions are available.
  double? get videoAspectRatio {
    if (!hasVideoDimensions) {
      return null;
    }

    if (videoHeight == 0) {
      return null;
    }

    return videoWidth! / videoHeight!;
  }

  /// Returns whether frames have been dropped.
  bool get hasDroppedFrames => droppedFrames > 0;

  /// Returns whether playback has rendered frames.
  bool get hasRenderedFrames => renderedFrames > 0;

  /// Returns whether decoding has produced frames.
  bool get hasDecodedFrames => decodedFrames > 0;

  /// Returns whether buffering has occurred.
  bool get hasBuffered => bufferCount > 0;

  /// Returns whether errors have been observed.
  bool get hasErrors => errorCount > 0;

  /// Returns whether recovery has been attempted.
  bool get hasRecovered => recoveryCount > 0;

  /// Returns whether fallback has been attempted.
  bool get hasFallback => fallbackCount > 0;

  /// Returns whether network traffic has been observed.
  bool get hasNetworkTraffic {
    return networkBytesReceived > 0 || networkBytesSent > 0;
  }

  /// Returns the total number of network bytes transferred.
  int get totalNetworkBytes {
    return networkBytesReceived + networkBytesSent;
  }

  /// Returns the number of frames that were not dropped.
  int get retainedFrames {
    final value = renderedFrames - droppedFrames;

    return value < 0 ? 0 : value;
  }

  /// Returns the dropped-frame ratio.
  double get droppedFrameRatio {
    final total = renderedFrames + droppedFrames;

    if (total <= 0) {
      return 0.0;
    }

    return droppedFrames / total;
  }

  /// Returns the approximate rendered frame ratio.
  double get renderEfficiency {
    final total = decodedFrames;

    if (total <= 0) {
      return 0.0;
    }

    return renderedFrames / total;
  }

  /// Returns whether the current metrics indicate frame loss.
  bool get hasFrameLoss => droppedFrameRatio > 0.0;

  /// Returns whether the current video dimensions are portrait.
  bool get isPortrait {
    final ratio = videoAspectRatio;

    return ratio != null && ratio < 1.0;
  }

  /// Returns whether the current video dimensions are landscape.
  bool get isLandscape {
    final ratio = videoAspectRatio;

    return ratio != null && ratio > 1.0;
  }

  /// Returns whether the current video dimensions are square.
  bool get isSquare {
    final ratio = videoAspectRatio;

    return ratio != null && ratio == 1.0;
  }

  /// Returns a metadata value by key.
  Object? metadataValue(String key) {
    return metadata[key];
  }

  /// Returns a typed metadata value.
  T? metadataAs<T>(String key) {
    final value = metadata[key];

    if (value is T) {
      return value;
    }

    return null;
  }

  /// Returns whether metadata contains [key].
  bool containsMetadata(String key) {
    return metadata.containsKey(key);
  }

  /// Creates a copy with updated values.
  ///
  /// Null values retain the existing values.
  PlayerMetrics copyWith({
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    Duration? bufferingDuration,
    double? playbackRate,
    double? volume,
    int? videoWidth,
    int? videoHeight,
    int? droppedFrames,
    int? renderedFrames,
    int? decodedFrames,
    int? bufferCount,
    int? errorCount,
    int? recoveryCount,
    int? fallbackCount,
    int? networkBytesReceived,
    int? networkBytesSent,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, Object?>? metadata,
  }) {
    return PlayerMetrics(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      bufferingDuration: bufferingDuration ?? this.bufferingDuration,
      playbackRate: playbackRate ?? this.playbackRate,
      volume: volume ?? this.volume,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      renderedFrames: renderedFrames ?? this.renderedFrames,
      decodedFrames: decodedFrames ?? this.decodedFrames,
      bufferCount: bufferCount ?? this.bufferCount,
      errorCount: errorCount ?? this.errorCount,
      recoveryCount: recoveryCount ?? this.recoveryCount,
      fallbackCount: fallbackCount ?? this.fallbackCount,
      networkBytesReceived: networkBytesReceived ?? this.networkBytesReceived,
      networkBytesSent: networkBytesSent ?? this.networkBytesSent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Creates a copy with a new playback position.
  PlayerMetrics withPosition(Duration value) {
    return copyWith(position: value);
  }

  /// Creates a copy with a new duration.
  PlayerMetrics withDuration(Duration value) {
    return copyWith(duration: value);
  }

  /// Creates a copy with a new buffered position.
  PlayerMetrics withBufferedPosition(Duration value) {
    return copyWith(bufferedPosition: value);
  }

  /// Creates a copy with a new buffering duration.
  PlayerMetrics withBufferingDuration(Duration value) {
    return copyWith(bufferingDuration: value);
  }

  /// Creates a copy with a new playback rate.
  PlayerMetrics withPlaybackRate(double value) {
    if (value <= 0.0) {
      throw ArgumentError.value(value, 'value', 'Playback rate must be greater than zero.');
    }

    return copyWith(playbackRate: value);
  }

  /// Creates a copy with a new volume.
  PlayerMetrics withVolume(double value) {
    if (value < 0.0 || value > 1.0) {
      throw ArgumentError.value(value, 'value', 'Volume must be between 0.0 and 1.0.');
    }

    return copyWith(volume: value);
  }

  /// Creates a copy with new video dimensions.
  PlayerMetrics withVideoDimensions({required int width, required int height}) {
    if (width < 0) {
      throw ArgumentError.value(width, 'width', 'Video width must not be negative.');
    }

    if (height < 0) {
      throw ArgumentError.value(height, 'height', 'Video height must not be negative.');
    }

    return copyWith(videoWidth: width, videoHeight: height);
  }

  /// Creates a copy with an updated dropped-frame count.
  PlayerMetrics withDroppedFrames(int value) {
    return copyWith(droppedFrames: _nonNegative(value));
  }

  /// Creates a copy with an updated rendered-frame count.
  PlayerMetrics withRenderedFrames(int value) {
    return copyWith(renderedFrames: _nonNegative(value));
  }

  /// Creates a copy with an updated decoded-frame count.
  PlayerMetrics withDecodedFrames(int value) {
    return copyWith(decodedFrames: _nonNegative(value));
  }

  /// Creates a copy with an updated buffering-event count.
  PlayerMetrics withBufferCount(int value) {
    return copyWith(bufferCount: _nonNegative(value));
  }

  /// Creates a copy with an updated error count.
  PlayerMetrics withErrorCount(int value) {
    return copyWith(errorCount: _nonNegative(value));
  }

  /// Creates a copy with an updated recovery count.
  PlayerMetrics withRecoveryCount(int value) {
    return copyWith(recoveryCount: _nonNegative(value));
  }

  /// Creates a copy with an updated fallback count.
  PlayerMetrics withFallbackCount(int value) {
    return copyWith(fallbackCount: _nonNegative(value));
  }

  /// Creates a copy with an updated received-byte count.
  PlayerMetrics withNetworkBytesReceived(int value) {
    return copyWith(networkBytesReceived: _nonNegative(value));
  }

  /// Creates a copy with an updated sent-byte count.
  PlayerMetrics withNetworkBytesSent(int value) {
    return copyWith(networkBytesSent: _nonNegative(value));
  }

  /// Creates a copy with one metadata entry added or replaced.
  PlayerMetrics withMetadata(String key, Object? value) {
    return copyWith(metadata: <String, Object?>{...metadata, key: value});
  }

  /// Creates a copy with multiple metadata entries added or replaced.
  PlayerMetrics withMetadataMap(Map<String, Object?> values) {
    if (values.isEmpty) {
      return this;
    }

    return copyWith(metadata: <String, Object?>{...metadata, ...values});
  }

  /// Creates a copy without video dimensions.
  PlayerMetrics withoutVideoDimensions() {
    return PlayerMetrics(
      position: position,
      duration: duration,
      bufferedPosition: bufferedPosition,
      bufferingDuration: bufferingDuration,
      playbackRate: playbackRate,
      volume: volume,
      droppedFrames: droppedFrames,
      renderedFrames: renderedFrames,
      decodedFrames: decodedFrames,
      bufferCount: bufferCount,
      errorCount: errorCount,
      recoveryCount: recoveryCount,
      fallbackCount: fallbackCount,
      networkBytesReceived: networkBytesReceived,
      networkBytesSent: networkBytesSent,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
    );
  }

  /// Creates a copy without playback position.
  PlayerMetrics withoutPosition() {
    return PlayerMetrics(
      duration: duration,
      bufferedPosition: bufferedPosition,
      bufferingDuration: bufferingDuration,
      playbackRate: playbackRate,
      volume: volume,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      droppedFrames: droppedFrames,
      renderedFrames: renderedFrames,
      decodedFrames: decodedFrames,
      bufferCount: bufferCount,
      errorCount: errorCount,
      recoveryCount: recoveryCount,
      fallbackCount: fallbackCount,
      networkBytesReceived: networkBytesReceived,
      networkBytesSent: networkBytesSent,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
    );
  }

  /// Creates a copy without duration information.
  PlayerMetrics withoutDuration() {
    return PlayerMetrics(
      position: position,
      bufferedPosition: bufferedPosition,
      bufferingDuration: bufferingDuration,
      playbackRate: playbackRate,
      volume: volume,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      droppedFrames: droppedFrames,
      renderedFrames: renderedFrames,
      decodedFrames: decodedFrames,
      bufferCount: bufferCount,
      errorCount: errorCount,
      recoveryCount: recoveryCount,
      fallbackCount: fallbackCount,
      networkBytesReceived: networkBytesReceived,
      networkBytesSent: networkBytesSent,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
    );
  }

  /// Creates a copy without metadata.
  PlayerMetrics clearMetadata() {
    if (metadata.isEmpty) {
      return this;
    }

    return copyWith(metadata: const <String, Object?>{});
  }

  /// Returns an empty metrics snapshot.
  static const PlayerMetrics empty = PlayerMetrics();

  /// Returns a metrics snapshot with no accumulated counters.
  static const PlayerMetrics initial = PlayerMetrics(playbackRate: 1.0, volume: 1.0);

  static int _nonNegative(int value) {
    return value < 0 ? 0 : value;
  }

  @override
  List<Object?> get props => <Object?>[
    position,
    duration,
    bufferedPosition,
    bufferingDuration,
    playbackRate,
    volume,
    videoWidth,
    videoHeight,
    droppedFrames,
    renderedFrames,
    decodedFrames,
    bufferCount,
    errorCount,
    recoveryCount,
    fallbackCount,
    networkBytesReceived,
    networkBytesSent,
    createdAt,
    updatedAt,
    metadata,
  ];

  @override
  String toString() {
    return 'PlayerMetrics('
        'position: $position, '
        'duration: $duration, '
        'bufferedPosition: $bufferedPosition, '
        'bufferingDuration: $bufferingDuration, '
        'playbackRate: $playbackRate, '
        'volume: $volume, '
        'videoWidth: $videoWidth, '
        'videoHeight: $videoHeight, '
        'droppedFrames: $droppedFrames, '
        'renderedFrames: $renderedFrames, '
        'decodedFrames: $decodedFrames, '
        'bufferCount: $bufferCount, '
        'errorCount: $errorCount, '
        'recoveryCount: $recoveryCount, '
        'fallbackCount: $fallbackCount, '
        'networkBytesReceived: $networkBytesReceived, '
        'networkBytesSent: $networkBytesSent, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt, '
        'metadata: $metadata'
        ')';
  }
}
