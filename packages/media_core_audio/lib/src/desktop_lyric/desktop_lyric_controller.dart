import 'dart:async';

import 'package:media_core_audio/src/desktop_lyric/desktop_lyric_state.dart';
import 'package:media_core_audio/src/desktop_lyric/desktop_lyric_transport.dart';
import 'package:media_core_audio/src/lyric/lyric_document.dart';
import 'package:media_core_audio/src/lyric/lyric_line.dart';
import 'package:media_core_audio/src/lyric/lyric_timeline.dart';
import 'package:media_core_audio/src/permission/audio_permission.dart';
import 'package:media_core_audio/src/permission/audio_permission_service.dart';
import 'package:media_core_audio/src/player/audio_playback_controller.dart';
import 'package:media_core_audio/src/player/audio_playback_state.dart';
import 'package:media_core_audio/src/track/music_track.dart';

/// Drives a desktop lyric overlay from an [AudioPlaybackController].
///
/// The controller is the whole of the logic: it follows the current track's
/// lyric, computes the active line/translation from the playback position, and
/// pushes a [DesktopLyricState] to its [DesktopLyricTransport] whenever
/// something a viewer could notice changed — a new line, a play/pause flip, a
/// style edit, a lock toggle.
///
/// The window itself is native and ships with this package (Windows layered
/// window, Android overlay window — see [DesktopLyricTransport]); on any other
/// platform [show] returns false and the caller should hide the feature.
///
/// Not pushed per position tick: an overlay is another window (its own
/// process on Android), and repainting it several times a second for identical
/// text is pure waste. Line changes and [minimumUpdateInterval]-spaced word
/// progress are what actually move the picture.
///
/// ```dart
/// final desktopLyric = DesktopLyricController(controller);
/// await desktopLyric.show();          // asks the host to draw the window
/// desktopLyric.setLocked(locked: true); // click-through
/// ```
final class DesktopLyricController {
  /// Creates a controller.
  ///
  /// [transport] defaults to the method-channel transport, which reports
  /// "unsupported" on hosts without an overlay implementation.
  DesktopLyricController(
    this.player, {
    DesktopLyricTransport? transport,
    AudioPermissionService? permissions,
    DesktopLyricStyle style = const DesktopLyricStyle(),
    this.minimumUpdateInterval = const Duration(milliseconds: 200),
    this.showTranslation = true,
    this.showRomanization = true,
    this.swapSecondary = false,
  }) : _transport = transport ?? MethodChannelDesktopLyricTransport(),
       _permissions = permissions ?? AudioPermissionService(),
       _style = style,
       _display = LyricDisplayOptions(
         showTranslation: showTranslation,
         showRomanization: showRomanization,
         swapTranslationAndRomanization: swapSecondary,
       ),
       _timeline = LyricTimeline(minimumUpdateInterval: minimumUpdateInterval);

  /// The music player this overlay follows.
  final AudioPlaybackController player;

  /// Minimum spacing of word-progress-only updates.
  final Duration minimumUpdateInterval;

  /// Whether translations are displayed when the lyric has them.
  final bool showTranslation;

  /// Whether romanizations are displayed when the lyric has them.
  final bool showRomanization;

  /// Whether romanization is shown above translation.
  final bool swapSecondary;

  final DesktopLyricTransport _transport;
  final AudioPermissionService _permissions;
  final LyricTimeline _timeline;

  StreamSubscription<AudioPlaybackState>? _stateSub;
  StreamSubscription<LyricPosition>? _lineSub;
  StreamSubscription<DesktopLyricAction>? _actionSub;
  StreamSubscription<AudioLoudness>? _loudnessSub;

  final StreamController<bool> _visibleChanges = StreamController<bool>.broadcast();
  final StreamController<bool> _lockedChanges = StreamController<bool>.broadcast();

  DesktopLyricStyle _style;
  LyricDisplayOptions _display;
  LyricDocument _document = LyricDocument.empty;
  DesktopLyricState? _lastPushed;
  Duration _appliedOffset = Duration.zero;

  /// Track whose lyric is currently loaded.
  ///
  /// Tracked here rather than read back from the player: the reload must fire
  /// exactly once per track change, and `state.track` is already the new one
  /// by the time the first position tick for it arrives.
  MusicTrack? _lyricTrack;

  bool _visible = false;
  bool _locked = false;
  bool _playing = false;
  bool _disposed = false;
  int _appliedLyricRevision = 0;

  /// The transport in use.
  DesktopLyricTransport get transport => _transport;

  /// Whether the overlay is currently shown.
  bool get visible => _visible;

  /// Whether the overlay ignores pointer input.
  bool get locked => _locked;

  /// Emits whenever the overlay is shown or hidden.
  ///
  /// Includes changes the overlay made itself — its own close button — so a
  /// host that persists the viewer's choice stays in sync with the window.
  Stream<bool> get visibleChanges => _visibleChanges.stream;

  /// Emits whenever the overlay's lock state changes, including its own
  /// lock/unlock button.
  Stream<bool> get lockedChanges => _lockedChanges.stream;

  /// Current styling.
  DesktopLyricStyle get style => _style;

  /// Which secondary tracks the overlay shows.
  LyricDisplayOptions get display => _display;

  /// The lyric being displayed.
  LyricDocument get document => _document;

  /// The last state pushed to the overlay.
  DesktopLyricState? get lastPushed => _lastPushed;

  /// Whether the host can draw an overlay at all.
  Future<bool> isSupported() => _transport.isSupported();

  /// Whether the overlay permission is granted right now.
  Future<bool> hasPermission() => _permissions.isGranted(AudioPermission.desktopLyricOverlay);

  /// Shows the overlay, obtaining the permission it needs first.
  ///
  /// One call, including the awkward part: where an overlay needs
  /// authorization (Android's "draw over other apps"), this awaits the system
  /// settings round trip — the user is sent there, and the future answers once
  /// they have toggled the switch. Returns false when the platform has no
  /// overlay or the user refused, in which case the caller simply does not
  /// offer the feature.
  Future<bool> show() async {
    if (_disposed) {
      return false;
    }

    if (!await _permissions.request(AudioPermission.desktopLyricOverlay)) {
      return false;
    }

    final supported = await _transport.show();

    if (!supported) {
      return false;
    }

    _visible = true;

    _visibleChanges.add(true);

    if (_stateSub == null) {
      _bind();
    }

    await _reloadLyric(force: true);
    _push(force: true);

    return true;
  }

  /// Hides the overlay, keeping the subscriptions (showing it again is cheap).
  Future<void> hide() async {
    if (_disposed || !_visible) {
      return;
    }

    _visible = false;

    _visibleChanges.add(false);

    unawaited(_transport.setLevels(momentary: -70, shortTerm: -70, active: false));
    await _transport.hide();
  }

  /// Shows the overlay when hidden and vice versa.
  Future<bool> toggle() async {
    if (_visible) {
      await hide();

      return false;
    }

    return await show();
  }

  /// Locks/unlocks the overlay.
  ///
  /// A locked overlay is click-through: it cannot be grabbed or clicked, which
  /// is what makes it usable over a full-screen video or game.
  Future<void> setLocked({required bool locked}) async {
    if (_disposed || _locked == locked) {
      return;
    }

    _locked = locked;
    _lockedChanges.add(locked);

    _push(force: true);
  }

  /// Replaces the styling.
  Future<void> setStyle(DesktopLyricStyle style) async {
    if (_disposed) {
      return;
    }

    _style = style;
    _push(force: true);
  }

  /// Replaces which secondary lyric tracks are shown.
  Future<void> setDisplayOptions(LyricDisplayOptions options) async {
    if (_disposed) {
      return;
    }

    _display = options;
    _push(force: true);
  }

  /// Moves/resizes the overlay, when the transport supports it.
  Future<void> setBounds({required double x, required double y, required double width, required double height}) {
    final transport = _transport;

    if (transport is MethodChannelDesktopLyricTransport) {
      return transport.setBounds(x: x, y: y, width: width, height: height);
    }

    return Future<void>.value();
  }

  /// Replaces the displayed lyric (a user-chosen sidecar file, for example).
  Future<void> setDocument(LyricDocument document) async {
    if (_disposed) {
      return;
    }

    _document = document;
    _timeline.setDocument(document);
    _push(force: true);
  }

  /// Releases subscriptions and the transport.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _stateSub?.cancel();
    _stateSub = null;
    await _lineSub?.cancel();
    _lineSub = null;
    await _actionSub?.cancel();
    _actionSub = null;
    await _loudnessSub?.cancel();
    _loudnessSub = null;

    await _timeline.dispose();
    await _transport.dispose();
    await _visibleChanges.close();
    await _lockedChanges.close();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _bind() {
    _stateSub = player.stateStream.listen(_onPlayerState);
    _lineSub = _timeline.changes.listen((_) => _push());
    _actionSub = _transport.actions.listen(_onAction);
    _loudnessSub = player.loudnessStream.listen(_onLoudness);
  }

  /// Forwards one loudness reading to the overlay's level bars. The
  /// adapter already throttles to a meter's pace, so this passes through.
  void _onLoudness(AudioLoudness levels) {
    if (_disposed) {
      return;
    }

    unawaited(
      _transport.setLevels(
        momentary: levels.momentary,
        shortTerm: levels.shortTerm,
        active: _visible && _playing,
      ),
    );
  }

  void _onPlayerState(AudioPlaybackState state) {
    if (_disposed) {
      return;
    }

    if (state.lyricOffset != _appliedOffset) {
      _appliedOffset = state.lyricOffset;
      _document = _document.withOffset(_appliedOffset);
      _timeline.setDocument(_document);
    }

    _timeline.update(state.position);

    // A play/pause flip changes the meter's active flag; the bars freeze
    // rather than keep dancing over a paused song.
    if (state.playing != _playing) {
      _playing = state.playing;
      if (!_playing) {
        unawaited(_transport.setLevels(momentary: -70, shortTerm: -70, active: false));
      }
    }

    // A host-supplied lyric (关联歌词) changes the words without changing the
    // track; the revision is what says so.
    final revisionChanged = state.lyricRevision != _appliedLyricRevision;

    if (revisionChanged) {
      _appliedLyricRevision = state.lyricRevision;
    }

    // A track change reloads the lyric; the position tick itself is already
    // handled above.
    if (state.track != _lyricTrack) {
      _lyricTrack = state.track;
      unawaited(_reloadLyric());
    } else if (revisionChanged) {
      unawaited(_reloadLyric(force: true));
    }

    _push();
  }

  Future<void> _reloadLyric({bool force = false}) async {
    // Captured so a slow load for a track the viewer already left cannot
    // overwrite the newer track's lyric with the previous song's words.
    final track = _lyricTrack;

    try {
      final document = await player.loadCurrentLyric(force: force);

      if (_disposed || !identical(track, _lyricTrack)) {
        return;
      }

      _document = document;
      _appliedOffset = player.lyricOffset;
      _timeline.setDocument(document);
      _push(force: true);
    } on Object catch (_) {
      // A lyric that cannot be loaded leaves the overlay showing its
      // placeholder; the music keeps playing.
    }
  }

  void _onAction(DesktopLyricAction action) {
    switch (action) {
      case DesktopLyricAction.previous:
        unawaited(player.previous());
      case DesktopLyricAction.toggle:
        unawaited(player.toggle());
      case DesktopLyricAction.next:
        unawaited(player.next());
      case DesktopLyricAction.close:
        unawaited(hide());
      case DesktopLyricAction.lock:
        unawaited(setLocked(locked: true));
      case DesktopLyricAction.unlock:
        unawaited(setLocked(locked: false));
    }
  }

  /// Pushes the current reading to the overlay.
  ///
  /// [force] bypasses the "nothing changed" check — used after a style, lock or
  /// visibility change, where the text may be identical but the window still
  /// needs the update.
  void _push({bool force = false}) {
    if (_disposed || !_visible) {
      return;
    }

    final reading = _timeline.current;
    final line = reading.line;
    final next = _document.lineAfter(reading.index);

    final state = DesktopLyricState(
      text: line == null ? '' : _displayText(line.text),
      translation: line?.secondaryText(
        showTranslation: _display.showTranslation,
        showRomanization: _display.showRomanization,
        swap: _display.swapTranslationAndRomanization,
      ),
      nextLine: next == null ? null : _displayText(next.text),
      progress: reading.lineProgress,
      playing: player.state.playing,
      locked: _locked,
      clickThrough: _locked,
      visible: _visible,
      style: _style,
      hasLyrics: !_document.isEmpty,
    );

    if (!force && _lastPushed != null && _sameFrame(_lastPushed!, state)) {
      return;
    }

    _lastPushed = state;

    unawaited(_transport.update(state));
  }

  /// Whether a push would change nothing a viewer could see.
  bool _sameFrame(DesktopLyricState a, DesktopLyricState b) {
    return a.text == b.text &&
        a.translation == b.translation &&
        a.nextLine == b.nextLine &&
        a.playing == b.playing &&
        a.locked == b.locked &&
        a.visible == b.visible &&
        a.hasLyrics == b.hasLyrics &&
        (b.progress - a.progress).abs() < 0.02 &&
        identical(a.style, b.style);
  }

  String _displayText(String text) => text.trim().isEmpty ? '♪' : text;
}
