import 'dart:async';

import 'lyric_document.dart';
import 'lyric_line.dart';

/// Tracks "which lyric line is current" for a moving playback position.
///
/// Separate from [LyricDocument] on purpose: the document is immutable data,
/// this is the small piece of stateful machinery every consumer (in-app view,
/// desktop lyric window, notification) would otherwise re-implement — a
/// cursor, a change event, and a throttle so a 200 ms position tick does not
/// turn into 5 updates per second per consumer.
///
/// Consumers feed positions in with [update]; line changes are emitted once,
/// which is what a desktop lyric overlay actually needs (it repaints a window,
/// not a stream of identical strings).
final class LyricTimeline {
  /// Creates a timeline over [document].
  LyricTimeline({LyricDocument document = LyricDocument.empty, this.minimumUpdateInterval = Duration.zero})
    : _document = document;

  /// Minimum spacing between emitted updates.
  ///
  /// [Duration.zero] emits on every line change (word-level timing wants
  /// that); a desktop overlay rendering whole lines can pass ~200 ms and get
  /// the same visual result for a fraction of the wakeups.
  final Duration minimumUpdateInterval;

  final StreamController<LyricPosition> _changes = StreamController<LyricPosition>.broadcast();

  LyricDocument _document;
  LyricPosition _current = LyricPosition.none;
  DateTime? _lastEmit;

  /// The document being tracked.
  LyricDocument get document => _document;

  /// The last computed reading.
  LyricPosition get current => _current;

  /// Emitted whenever the reading changes (new line, or a new word when the
  /// line carries word timing).
  Stream<LyricPosition> get changes => _changes.stream;

  /// Replaces the document and resets the cursor.
  void setDocument(LyricDocument document) {
    _document = document;
    _current = LyricPosition.none;
    _lastEmit = null;
  }

  /// Whether a document is loaded.
  bool get hasLyrics => !_document.isEmpty;

  /// Feeds a playback position.
  ///
  /// Returns the new reading. Emits on [changes] only when the active line (or
  /// active word) moved on, and not more often than [minimumUpdateInterval].
  LyricPosition update(Duration position) {
    final next = _document.positionAt(position);
    final previous = _current;

    final changedLine = next.index != previous.index;
    final changedWord = next.wordIndex != previous.wordIndex;

    _current = next;

    if (!_shouldEmit(changedLine, changedWord)) {
      return next;
    }

    if (!_changes.isClosed) {
      _changes.add(next);
    }

    _lastEmit = DateTime.now();

    return next;
  }

  bool _shouldEmit(bool changedLine, bool changedWord) {
    if (!changedLine && !changedWord) {
      return false;
    }

    if (minimumUpdateInterval <= Duration.zero) {
      return true;
    }

    // A line change is always worth emitting — holding it back would make the
    // display lag behind the audio. Only word-level churn is throttled.
    if (changedLine) {
      return true;
    }

    final last = _lastEmit;

    return last == null || DateTime.now().difference(last) >= minimumUpdateInterval;
  }

  /// Releases the change stream.
  Future<void> dispose() async {
    await _changes.close();
  }
}
