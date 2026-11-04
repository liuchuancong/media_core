import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';

/// The live open table is a measured set, not a preference: these numbers are
/// the reference's own cold A/B on a Bilibili stream (first frame 1802 ms at
/// 2 MiB / 2 s, 708 ms at these), and `network-timeout` exists because a
/// line that answers at 6 s reads to the viewer as "the room never opens".
///
/// The table is deliberately *silent* about the live buffer sizes the
/// reference also sets: its `demuxer-readahead-secs: 2` means "collect two
/// seconds before playing", which trades the first frame for smoothness —
/// the opposite trade from this one. If a future change wants a bigger
/// read-ahead, it should be measured (the room logs `room-open` with a
/// `firstFrame` segment for exactly that A/B), not copied.
void main() {
  group('mpv live open defaults', () {
    test('carry the measured probe budget', () {
      expect(mpvLiveOpenDefaults['demuxer-lavf-probesize'], '1048576');
      expect(mpvLiveOpenDefaults['demuxer-lavf-analyzeduration'], '1');
    });

    test('keep a live buffer in memory and give a slow line its time', () {
      expect(mpvLiveOpenDefaults['cache-on-disk'], 'no');
      expect(mpvLiveOpenDefaults['network-timeout'], '15');
      expect(mpvLiveOpenDefaults['hwdec-software-fallback'], '1');
    });

    test('do not delay the first frame for a read-ahead window', () {
      expect(mpvLiveOpenDefaults.containsKey('demuxer-readahead-secs'), isFalse);
      expect(mpvLiveOpenDefaults.containsKey('cache-secs'), isFalse);
    });
  });
}
