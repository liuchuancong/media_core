/// The PCM-tap feasibility probe (spectrum plan stages B1 + B2).
///
/// B1 mounts `astats` into mpv's `af` chain and reads the per-frame levels
/// back through the `af-metadata/tap` property — the same observed-property
/// route the EBU R128 loudness probe already uses in production. B2
/// measures the channel itself: the metadata callback rate in Hz and the
/// wall-clock cost of parsing one frame's string, so the plan's ≥30 Hz /
/// <2 ms budgets can be checked on a real machine instead of assumed.
library;

import 'dart:async';

import 'package:media_core/media_core.dart';
import 'package:media_kit/media_kit.dart' as mk;

/// One frame of level readings, in dB (relative to full scale).
///
/// `null` fields mean "no reading this frame": FFmpeg prints `-inf` and
/// `nan` for silent or unmeasured windows, and those are kept apart from a
/// real number instead of being clamped into one.
final class AudioTapLevelFrame {
  /// Creates one frame of readings.
  const AudioTapLevelFrame({required this.overallRmsDb, required this.overallPeakDb, required this.channels});

  /// The mix's overall RMS level, `lavfi.astats.Overall.RMS_level`.
  final double? overallRmsDb;

  /// The mix's overall peak level, `lavfi.astats.Overall.Peak_level`.
  final double? overallPeakDb;

  /// Per-channel readings, keyed by the channel index astats reports.
  final Map<int, AudioTapChannelLevels> channels;
}

/// One channel's pair of readings.
final class AudioTapChannelLevels {
  /// Creates the pair; either side may be absent for a given frame.
  const AudioTapChannelLevels({this.rmsDb, this.peakDb});

  /// This channel's RMS level in dB.
  final double? rmsDb;

  /// This channel's peak level in dB.
  final double? peakDb;
}

/// The B2 measurements for the window just closed.
final class AudioTapStats {
  /// Creates one measurement.
  const AudioTapStats({
    required this.frames,
    required this.hz,
    required this.lastParseUs,
    required this.maxParseUs,
    required this.window,
  });

  /// Metadata callbacks since the probe started.
  final int frames;

  /// Measured callback rate over the rolling window; 0 before two frames.
  final double hz;

  /// The last frame's parse cost, microseconds.
  final int lastParseUs;

  /// The worst parse cost seen since start, microseconds.
  final int maxParseUs;

  /// The window the Hz was measured over, milliseconds.
  final int window;
}

/// Attaches the astats probe to one media_kit player.
///
/// The probe owns its filter entry: [start] mounts `astats` at the tail of
/// `af` (an append, so an existing chain keeps its position) and begins
/// observing; [stop] unobserves and removes the entry again. The host never
/// edits `af` itself for the probe's sake.
final class MediaKitAudioTapProbe {
  /// Creates a probe for the given player.
  MediaKitAudioTapProbe(this._player);

  /// The filter entry the probe appends to `af`.
  static const String filterEntry = '@tap:lavfi=[astats=metadata=1:reset=1]';

  /// The property the tap reads. mpv only publishes filter metadata under
  /// `af-metadata/<label>`, so the mount carries the [filterEntry]'s label.
  static const String metadataProperty = 'af-metadata/tap';

  final mk.Player _player;

  final StreamController<AudioTapLevelFrame> _frames =
      StreamController<AudioTapLevelFrame>.broadcast();
  final StreamController<AudioTapStats> _stats = StreamController<AudioTapStats>.broadcast();

  var _framesSeen = 0;
  var _maxParseUs = 0;
  var _lastParseUs = 0;
  var _lastFrameAt = DateTime(0);
  final List<int> _intervalsMs = <int>[];
  DateTime _summaryAt = DateTime(0);

  /// The parsed level frames, one per metadata callback.
  Stream<AudioTapLevelFrame> get frames => _frames.stream;

  /// The B2 measurements, pushed on every callback.
  Stream<AudioTapStats> get stats => _stats.stream;

  /// Whether the observer is installed.
  bool get running => _observing;

  var _observing = false;

  /// Mounts the filter and starts observing.
  ///
  /// Observing must start before the mount: astats only writes metadata for
  /// frames that pass it, and the first callbacks are the evidence B1 needs.
  Future<bool> start() {
    if (_observing) {
      return Future<bool>.value(true);
    }
    _reset();
    if (!_observe()) {
      return Future<bool>.value(false);
    }
    _observing = true;
    return _run(<String>['change-list', 'af', 'append', filterEntry]);
  }

  /// Stops observing and removes the filter entry.
  Future<void> stop() async {
    if (!_observing) return;
    _observing = false;
    _unobserve();
    await _run(<String>['change-list', 'af', 'remove', filterEntry]);
  }

  void _reset() {
    _framesSeen = 0;
    _maxParseUs = 0;
    _lastParseUs = 0;
    _lastFrameAt = DateTime(0);
    _intervalsMs.clear();
    _summaryAt = DateTime.now();
  }

  // The observer APIs live on NativePlayer, not on the shared platform type;
  // the loudness probe reaches them the same dynamic way. A platform without
  // them (web) answers false and the probe never claims to run.
  bool _observe() {
    try {
      // NativePlayer-only API, reached the way the loudness probe reaches it.
      // ignore: avoid_dynamic_calls
      (_player.platform as dynamic).observeProperty?.call(metadataProperty, (dynamic value) async {
        _onMetadata(value?.toString() ?? '');
      });
      return true;
    } on Object catch (error, stackTrace) {
      MediaCoreLog.warning(
        LogCategory.audio,
        'audio tap observe \$metadataProperty failed: \$error',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  void _unobserve() {
    try {
      // NativePlayer-only API, matched to the observer above.
      // ignore: avoid_dynamic_calls
      (_player.platform as dynamic).unobserveProperty?.call(metadataProperty);
    } on Object {
      // The player is going away; nothing left to unobserve.
    }
  }

  Future<bool> _run(List<String> command) async {
    try {
      await (_player.platform as dynamic).command(command);
      return true;
    } on Object catch (error) {
      MediaCoreLog.warning(LogCategory.audio, 'audio tap command rejected "${command.join(' ')}": $error');
      return false;
    }
  }

  void _onMetadata(String value) {
    if (!_observing || value.isEmpty) return;

    final parseWatch = Stopwatch()..start();
    final frame = parseAstatsMetadata(value);
    parseWatch.stop();
    _lastParseUs = parseWatch.elapsedMicroseconds;
    if (_lastParseUs > _maxParseUs) {
      _maxParseUs = _lastParseUs;
    }

    final now = DateTime.now();
    if (_lastFrameAt.year > 1) {
      _intervalsMs.add(now.difference(_lastFrameAt).inMilliseconds);
      // A rolling two seconds of intervals is plenty for a rate estimate.
      while (_intervalsMs.length > 200) {
        _intervalsMs.removeAt(0);
      }
    }
    _lastFrameAt = now;
    _framesSeen++;

    if (frame != null && (frame.overallRmsDb != null || frame.channels.isNotEmpty)) {
      _frames.add(frame);
    }
    _stats.add(_currentStats(now));

    if (now.difference(_summaryAt) >= const Duration(seconds: 5)) {
      _summaryAt = now;
      final stats = _currentStats(now);
      MediaCoreLog.info(
        LogCategory.audio,
        'audio tap B1/B2: ${stats.hz.toStringAsFixed(1)} Hz, '
        'parse ${stats.lastParseUs} us (max ${stats.maxParseUs} us), '
        'overall rms ${frame?.overallRmsDb?.toStringAsFixed(1) ?? '-'} dB',
      );
    }
  }

  AudioTapStats _currentStats(DateTime now) {
    var hz = 0.0;
    if (_intervalsMs.isNotEmpty) {
      final spanMs = _intervalsMs.reduce((a, b) => a + b);
      if (spanMs > 0) {
        hz = _intervalsMs.length * 1000 / spanMs;
      }
    }
    return AudioTapStats(
      frames: _framesSeen,
      hz: hz,
      lastParseUs: _lastParseUs,
      maxParseUs: _maxParseUs,
      window: _lastFrameAt.year > 1 ? now.difference(_lastFrameAt).inMilliseconds + _intervalsMs.fold(0, (a, b) => a + b) : 0,
    );
  }
}

/// Parses one `af-metadata` string into level readings.
///
/// The string arrives as `+lavfi.astats.Overall.RMS_level=-23.1
/// +lavfi.astats.0.Peak_level=-3.9+…`; the sign can belong to the value, so
/// entries cannot be split on `+`. `-inf` reads as negative infinity, `nan`
/// and anything unparsable as "no reading".
AudioTapLevelFrame? parseAstatsMetadata(String raw) {
  final pattern = RegExp(
    r'lavfi\.astats\.(Overall|\d+)\.(RMS_level|Peak_level)=(-?inf|nan|[-+]?\d+(?:\.\d+)?)',
  );
  var overallRms = false;
  var overallPeak = false;
  double? rms;
  double? peak;
  final channels = <int, AudioTapChannelLevels>{};
  final channelRms = <int, double?>{};
  final channelPeak = <int, double?>{};

  for (final match in pattern.allMatches(raw)) {
    final value = switch (match.group(3)) {
      '-inf' => double.negativeInfinity,
      'inf' => double.infinity,
      'nan' => null,
      final text => double.tryParse(text!),
    };
    final channel = match.group(1)!;
    final field = match.group(2)!;
    if (channel == 'Overall') {
      if (field == 'RMS_level') {
        rms = value;
        overallRms = true;
      } else {
        peak = value;
        overallPeak = true;
      }
    } else {
      final index = int.tryParse(channel);
      if (index == null) continue;
      if (field == 'RMS_level') {
        channelRms[index] = value;
      } else {
        channelPeak[index] = value;
      }
    }
  }

  if (!overallRms && !overallPeak && channelRms.isEmpty && channelPeak.isEmpty) return null;
  for (final index in channelRms.keys) {
    channels[index] = AudioTapChannelLevels(rmsDb: channelRms[index], peakDb: channelPeak[index]);
  }
  for (final index in channelPeak.keys) {
    channels.putIfAbsent(index, () => AudioTapChannelLevels(rmsDb: channelRms[index], peakDb: channelPeak[index]));
  }
  return AudioTapLevelFrame(overallRmsDb: rms, overallPeakDb: peak, channels: channels);
}
