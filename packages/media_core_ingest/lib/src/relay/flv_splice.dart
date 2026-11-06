import 'dart:typed_data';

/// Byte-level access to one complete FLV tag: the 11-byte tag header, the
/// payload and the trailing PreviousTagSize, per the Adobe FLV specification
/// v10.1 annex E and the Enhanced RTMP/FLV extension for HEVC.
abstract final class FlvTagProbe {
  /// Audio tag type.
  static const int audio = 8;

  /// Video tag type.
  static const int video = 9;

  /// Script data tag type.
  static const int script = 18;

  /// Tag header length.
  static const int headerLength = 11;

  /// The tag type.
  static int type(Uint8List tag) => tag[0] & 0x1f;

  /// Timestamp in milliseconds, 24 bits plus the extension byte.
  static int timestamp(Uint8List tag) => (tag[7] << 24) | (tag[4] << 16) | (tag[5] << 8) | tag[6];

  /// A copy of [tag] carrying [timestamp], wrapped to 32 bits.
  static Uint8List withTimestamp(Uint8List tag, int timestamp) {
    final copy = Uint8List.fromList(tag);
    final value = timestamp & 0xffffffff;
    copy[4] = (value >> 16) & 0xff;
    copy[5] = (value >> 8) & 0xff;
    copy[6] = value & 0xff;
    copy[7] = (value >> 24) & 0xff;
    return copy;
  }

  /// A video decoder configuration: an AVC or legacy-HEVC sequence header, or
  /// an Enhanced FLV SequenceStart.
  static bool isVideoConfig(Uint8List tag) {
    if (type(tag) != video || tag.length < headerLength + 2 + 4) {
      return false;
    }
    if (_enhanced(tag)) {
      return (tag[headerLength] & 0x0f) == 0;
    }
    final codec = tag[headerLength] & 0x0f;
    return (codec == 7 || codec == 12) && tag[headerLength + 1] == 0;
  }

  /// An AAC AudioSpecificConfig.
  static bool isAudioConfig(Uint8List tag) =>
      type(tag) == audio &&
      tag.length > headerLength + 2 + 4 &&
      (tag[headerLength] >> 4) == 10 &&
      tag[headerLength + 1] == 0;

  /// A video keyframe carrying picture data, not a configuration or an
  /// end-of-sequence marker.
  static bool isVideoKeyframe(Uint8List tag) {
    if (type(tag) != video || tag.length < headerLength + 2 + 4 || _frameType(tag) != 1) {
      return false;
    }
    if (_enhanced(tag)) {
      final packetType = tag[headerLength] & 0x0f;
      return packetType == 1 || packetType == 3;
    }
    final codec = tag[headerLength] & 0x0f;
    if (codec == 7 || codec == 12) {
      return tag[headerLength + 1] == 1;
    }
    return true;
  }

  /// Whether two tags carry the same payload; timestamps may differ.
  static bool samePayload(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = headerLength; i < a.length - 4; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static bool _enhanced(Uint8List tag) => (tag[headerLength] & 0x80) != 0;

  static int _frameType(Uint8List tag) => (tag[headerLength] >> 4) & 0x07;
}

/// Where a renewed connection's timeline sits relative to the delivered output.
enum FlvSpliceAlignment {
  /// Same timeline as the delivered output: the old stream is forwarded until
  /// it reaches the new keyframe's output position, then the new one continues
  /// from its keyframe, so the player sees one timeline without gap or repeat.
  sameTimeline,

  /// Another timeline, beyond the alignment window: the new stream is shifted
  /// to continue the delivered one and takes over at once.
  shifted,
}

/// What the outgoing connection's tag should do while a splice point is armed.
enum FlvSpliceOldTagAction {
  /// Forward through [FlvSpliceTimeline.accept].
  forward,

  /// Drop: the new connection covers this position.
  drop,

  /// Cut to the new connection now; the tag itself is dropped.
  switchNow,
}

/// One splice point on a renewed connection: where its usable keyframe lands
/// on the delivered output timeline and how the cut behaves.
///
/// Produced by [FlvSplicePolicy.planConnection]; every position is in
/// milliseconds, raw meaning as the connection sent it.
final class FlvSplicePlan {
  /// Creates the plan.
  const FlvSplicePlan({required this.alignment, required this.keyframeTimestamp, required this.outputOffset});

  /// Where the renewed connection's timeline sits relative to the output.
  final FlvSpliceAlignment alignment;

  /// The new keyframe's raw timestamp.
  final int keyframeTimestamp;

  /// Milliseconds added to every new-connection timestamp.
  final int outputOffset;

  /// Whether the cut waits for the old stream to reach [switchAt].
  bool get isSameTimeline => alignment == FlvSpliceAlignment.sameTimeline;

  /// Output timestamp of the first new keyframe.
  int get switchAt => keyframeTimestamp + outputOffset;

  /// A new-connection raw timestamp on the delivered output timeline.
  int outputTimestamp(int rawTimestamp) => rawTimestamp + outputOffset;

  /// [tag] rewritten onto the output timeline; the same instance when no
  /// shift applies.
  Uint8List rewriteTag(Uint8List tag) =>
      outputOffset == 0 ? tag : FlvTagProbe.withTimestamp(tag, FlvTagProbe.timestamp(tag) + outputOffset);

  /// Whether this keyframe is at or behind what the old connection already
  /// delivered, so the keyframe search must continue past it. Only a
  /// same-timeline connection can deliver behind the output; a shifted one
  /// takes over wherever it starts.
  bool isAlreadyDelivered({required int? deliveredLastVideo}) {
    final delivered = deliveredLastVideo;
    return isSameTimeline && delivered != null && switchAt <= delivered;
  }

  /// The fate of the outgoing connection's tag while this plan is armed.
  ///
  /// A shifted plan supersedes the old connection outright. A same-timeline
  /// plan forwards configurations and everything before the cut, cuts on the
  /// first picture tag at or past [switchAt] and drops old audio from there
  /// on.
  FlvSpliceOldTagAction judgeOldTag(Uint8List tag) {
    if (!isSameTimeline) {
      return FlvSpliceOldTagAction.switchNow;
    }
    final type = FlvTagProbe.type(tag);
    if (type != FlvTagProbe.video && type != FlvTagProbe.audio) {
      return FlvSpliceOldTagAction.forward;
    }
    final isConfig = FlvTagProbe.isVideoConfig(tag) || FlvTagProbe.isAudioConfig(tag);
    if (isConfig) {
      return FlvSpliceOldTagAction.forward;
    }
    final output = FlvTagProbe.timestamp(tag) + outputOffset;
    if (output < switchAt) {
      return FlvSpliceOldTagAction.forward;
    }
    return type == FlvTagProbe.video ? FlvSpliceOldTagAction.switchNow : FlvSpliceOldTagAction.drop;
  }
}

/// The splice decisions: timeline alignment for a renewed connection and the
/// timestamp shift each case uses.
final class FlvSplicePolicy {
  /// Creates the policy; the defaults follow the reference behaviour of a
  /// 60 s alignment window and a 40 ms step behind the last delivered video
  /// tag for a shifted keyframe.
  const FlvSplicePolicy({
    this.alignmentWindow = const Duration(seconds: 60),
    this.shiftGap = const Duration(milliseconds: 40),
  });

  /// A renewed connection whose first video timestamp is further than this
  /// from the delivered position is on another timeline and gets shifted.
  final Duration alignmentWindow;

  /// Step between the last delivered video tag and a shifted keyframe.
  final Duration shiftGap;

  /// Decides how a renewed connection joins the delivered output.
  ///
  /// [keyframeTimestamp] is the raw timestamp of the connection's usable
  /// keyframe, [deliveredLastVideo] the last video position already emitted
  /// and [deliveredOffset] the output offset in force. A first connection
  /// passes a null [deliveredLastVideo] and joins unshifted.
  FlvSplicePlan planConnection({
    required int keyframeTimestamp,
    required int? deliveredLastVideo,
    required int deliveredOffset,
  }) {
    final delivered = deliveredLastVideo;
    final sameTimeline =
        delivered == null ||
        (keyframeTimestamp - (delivered - deliveredOffset)).abs() <= alignmentWindow.inMilliseconds;
    if (sameTimeline) {
      return FlvSplicePlan(
        alignment: FlvSpliceAlignment.sameTimeline,
        keyframeTimestamp: keyframeTimestamp,
        outputOffset: deliveredOffset,
      );
    }
    return FlvSplicePlan(
      alignment: FlvSpliceAlignment.shifted,
      keyframeTimestamp: keyframeTimestamp,
      outputOffset: delivered + shiftGap.inMilliseconds - keyframeTimestamp,
    );
  }
}

/// The delivered output's timestamp ledger: the offset in force, the last
/// video and audio positions and the codec configurations, with the drop
/// rules that keep a spliced stream monotonic.
///
/// Pure state, no I/O: a relay feeds every tag of the active connection
/// through [accept] and emits what comes back.
final class FlvSpliceTimeline {
  /// Creates the ledger for a stream that starts at [outputOffset].
  FlvSpliceTimeline({this.outputOffset = 0});

  /// Milliseconds added to every tag of the current connection.
  int outputOffset;

  int? _lastVideo;
  int? _lastAudio;
  Uint8List? _videoConfig;
  Uint8List? _audioConfig;
  bool _hasSwitched = false;

  /// Last delivered video position on the output timeline, if any.
  int? get deliveredLastVideo => _lastVideo;

  /// Last delivered audio position on the output timeline, if any.
  int? get deliveredLastAudio => _lastAudio;

  /// Whether a splice has already happened; script tags are forwarded only
  /// before the first one.
  bool get hasSwitched => _hasSwitched;

  /// Applies [plan] at the switch: the ledger continues on the plan's offset.
  void adopt(FlvSplicePlan plan) {
    outputOffset = plan.outputOffset;
    _hasSwitched = true;
  }

  /// Whether the switch must re-send an incoming video configuration: never
  /// seen, or a different payload than the last one delivered.
  bool needsVideoConfig(Uint8List incoming) =>
      _videoConfig == null || !FlvTagProbe.samePayload(incoming, _videoConfig!);

  /// Whether the switch must re-send an incoming audio configuration.
  bool needsAudioConfig(Uint8List incoming) =>
      _audioConfig == null || !FlvTagProbe.samePayload(incoming, _audioConfig!);

  /// Takes one complete tag and answers the bytes to emit, or null to drop
  /// it: script tags after the first switch, negative positions, video older
  /// than the delivered video and audio at or below the delivered audio.
  Uint8List? accept(Uint8List tag) {
    final type = FlvTagProbe.type(tag);
    if (type == FlvTagProbe.script) {
      return _hasSwitched ? null : tag;
    }
    final ts = FlvTagProbe.timestamp(tag) + outputOffset;
    if (ts < 0) {
      return null;
    }
    if (FlvTagProbe.isVideoConfig(tag)) {
      _videoConfig = tag;
    } else if (FlvTagProbe.isAudioConfig(tag)) {
      _audioConfig = tag;
    } else if (type == FlvTagProbe.video) {
      final last = _lastVideo;
      if (last != null && ts < last) {
        return null;
      }
      _lastVideo = ts;
    } else if (type == FlvTagProbe.audio) {
      final last = _lastAudio;
      if (last != null && ts <= last) {
        return null;
      }
      _lastAudio = ts;
    }
    return outputOffset == 0 ? tag : FlvTagProbe.withTimestamp(tag, ts);
  }
}
