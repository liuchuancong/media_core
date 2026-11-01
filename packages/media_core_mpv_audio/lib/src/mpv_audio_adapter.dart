import 'dart:async';

import 'package:media_core/media_core.dart';

import 'package:mpv_audio_kit/mpv_audio_kit.dart' as mak;

final LogModule _log = MediaCoreLog.of(LogCategory.player);

/// Characters a header line cannot carry: a colon would end the name, and a
/// CR, LF or NUL would split or inject a request line.
final RegExp _kForbiddenHeaderName = RegExp(r'[\r\n,:\x00]');
final RegExp _kForbiddenHeaderValue = RegExp(r'[\r\n\x00]');

/// [PlayerAdapter] implementation backed by mpv_audio_kit — the patched
/// libmpv audio engine.
///
/// This adapter is audio-only by nature: the engine beneath has no video
/// output surface, so the capabilities say so and the contract's video
/// seams stay at their honest defaults. What it uniquely carries are the
/// engine's own extras — the PCM/FFT taps, the typed effects chain, the
/// media session — which the host reaches through [player] rather than
/// through invented adapter interfaces.
///
/// Engine semantics:
///
/// - playback commands map one-to-one (`open`/`play`/`pause`/`stop`/
///   `seek`/`setVolume`/`setRate`)
/// - engine events forward through the base's event vocabulary
///   (playing/paused/completed/buffering/position/duration)
/// - errors surface as open failures while a source is opening, and as
///   logged events afterwards — playback never dies silently
/// - the player instance is the adapter's own unless one is injected,
///   and it is disposed with the adapter
final class MpvAudioPlayerAdapter extends PlayerAdapterBase {
  /// Creates an mpv_audio_kit adapter.
  MpvAudioPlayerAdapter({
    super.id = kMpvAudioBackendId,
    super.capabilities = defaultCapabilities,
    mak.Player? player,
    this.configuration,
  }) : _injectedPlayer = player;

  /// Backend id the adapter registers under.
  static const String kMpvAudioBackendId = 'mpv_audio';
  final mak.Player? _injectedPlayer;

  /// The engine's own player configuration, applied verbatim when the
  /// adapter creates its player; null uses the engine's defaults.
  final mak.PlayerConfiguration? configuration;

  mak.Player? _player;
  final List<StreamSubscription<Object?>> _subscriptions = <StreamSubscription<Object?>>[];

  /// The adapter's capabilities: an audio-only engine that plays, seeks,
  /// rates and volumes, and nothing else. Every declaration here is a
  /// seam the adapter really answers.
  static const PlayerAdapterCapabilities defaultCapabilities = PlayerAdapterCapabilities(
    supportsPause: true,
    supportsStop: true,
    supportsSeek: true,
    supportsRateControl: true,
    supportsVolumeControl: true,
    supportsAudioOnly: true,
  );

  /// The engine's own player — the door to what this backend uniquely
  /// carries: `stream.fft` / `stream.pcm` / `stream.waveform` taps,
  /// `setAudioEffects` with the typed effect classes, `setMediaSession`,
  /// and the playlist/jump surface. Null before [initialize], after
  /// [dispose], and when the adapter runs on a platform without the
  /// engine.
  mak.Player? get player => _player;

  @override
  Future<void> onInitialize(PlayerAdapterContext context) async {
    mak.MpvAudioKit.ensureInitialized();
    _player = _injectedPlayer ?? mak.Player(configuration: configuration ?? const mak.PlayerConfiguration());
    _wire(_player!);
  }

  void _wire(mak.Player player) {
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      player.stream.playing.listen((playing) {
        if (playing) {
          emitPlaying();
        } else {
          // The engine reports !playing both for a user pause and while a
          // source loads; paused is only emitted once playback had begun.
          if (state.playback == PlayerPlaybackState.playing) {
            emitPaused();
          }
        }
      }),
      player.stream.completed.listen((completed) {
        if (completed) emitCompleted();
      }),
      player.stream.buffering.listen((buffering) {
        emitBuffering(buffering: buffering);
      }),
      player.stream.position.listen(emitPositionChanged),
      player.stream.duration.listen((duration) {
        if (duration > Duration.zero) emitDurationChanged(duration);
      }),
      player.stream.error.listen((error) {
        _log.warning('mpv_audio engine error: $error');
      }),
    ]);
  }

  @override
  Future<void> onOpen(PlayerSource source) async {
    final player = _player;
    if (player == null) {
      throw StateError('mpv_audio adapter has no engine to open with');
    }
    await _applyNetworkHeaders(player, source.headers);
    await player.open(mak.Media(source.uri.toString()));
  }

  /// Writes the source's headers into mpv's network options, ahead of the
  /// load.
  ///
  /// `Media.httpHeaders` cannot carry a comma: the engine comma-joins the
  /// entries and rejects the character in any value, while a browser user
  /// agent always carries one (`KHTML, like Gecko`). With that UA in the map,
  /// every music open failed with `Invalid argument (header value)` before
  /// even reaching mpv. mpv's list parser does accept `\,`, and `user-agent` /
  /// `referrer` (mpv writes the `Referer` line from it) are plain string
  /// options, so the exact values go through the raw option surface instead.
  /// A header the request line cannot express at all (CR, LF, NUL) is dropped
  /// with a warning rather than failing an otherwise playable load.
  ///
  /// Only the next open reads these options, and this engine plays one file
  /// at a time, so the entry being loaded is always the one written here.
  Future<void> _applyNetworkHeaders(mak.Player player, SourceHeaders? headers) async {
    String? userAgent;
    String? referrer;
    final fields = <String>[];

    for (final entry in headers?.values.entries ?? const <MapEntry<String, String>>[]) {
      final name = entry.key.trim();

      switch (name.toLowerCase()) {
        case 'user-agent':
          userAgent = entry.value;
        case 'referer' || 'referrer':
          referrer = entry.value;
        default:
          if (name.isEmpty || _kForbiddenHeaderName.hasMatch(name) || _kForbiddenHeaderValue.hasMatch(entry.value)) {
            _log.warning('dropped http header mpv cannot carry', fields: <String, Object?>{'header': name});
          } else {
            // `\,` keeps a comma inside the value while separating fields.
            fields.add('${name.replaceAll(',', r'\,')}: ${entry.value.replaceAll(',', r'\,')}');
          }
      }
    }

    try {
      // Empty values clear the previous track's options: a source without a
      // UA must not send the last song's identity.
      await player.setRawProperty('options/user-agent', userAgent ?? '');
      await player.setRawProperty('options/referrer', referrer ?? '');
      if (fields.isEmpty) {
        // Writing an empty list would leave one blank header line on the
        // request; the list's own clear operation is the honest reset.
        await player.sendRawCommand(const <String>['change-list', 'http-header-fields', 'clr', '']);
      } else {
        await player.setRawProperty('options/http-header-fields', fields.join(','));
      }
    } on Object catch (error) {
      // Headers are best-effort: a rejected option must not take the whole
      // track down when the stream itself is fine without it.
      _log.warning('mpv rejected the http headers', error: error);
    }
  }

  @override
  Future<void> onPlay() async {
    await _player?.play();
  }

  @override
  Future<void> onPause() async {
    await _player?.pause();
  }

  @override
  Future<void> onStop() async {
    await _player?.stop();
  }

  @override
  Future<void> onSeek(Duration position) async {
    await _player?.seek(position);
  }

  @override
  Future<void> onSetVolume(double volume) async {
    await _player?.setVolume(volume);
  }

  @override
  Future<void> onSetRate(double rate) async {
    await _player?.setRate(rate);
  }

  @override
  Future<void> onClose() async {
    await _player?.stop();
  }

  @override
  Future<void> onDispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    if (identical(player, _injectedPlayer)) {
      // An injected player belongs to whoever injected it; only the
      // adapter's own engine is torn down here.
      return;
    }
    await player?.dispose();
  }
}
