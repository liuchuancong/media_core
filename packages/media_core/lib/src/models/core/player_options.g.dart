// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_options.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerOptions extends PlayerOptions {
  @override
  final bool autoPlay;
  @override
  final bool autoInitialize;
  @override
  final bool loop;
  @override
  final bool muted;
  @override
  final double volume;
  @override
  final double playbackRate;
  @override
  final bool preload;
  @override
  final bool keepAlive;
  @override
  final bool preferHardwareDecoding;
  @override
  final bool enableAudio;
  @override
  final bool enableVideo;
  @override
  final bool enableSubtitles;
  @override
  final bool enableBuffering;
  @override
  final bool enableRecovery;
  @override
  final bool enableFallback;
  @override
  final bool enableMetrics;
  @override
  final bool enableDiagnostics;
  @override
  final SourceId? sourceId;
  @override
  final int maxRecoveryAttempts;
  @override
  final int maxFallbackAttempts;

  factory _$PlayerOptions([void Function(PlayerOptionsBuilder)? updates]) =>
      (PlayerOptionsBuilder()..update(updates))._build();

  _$PlayerOptions._({
    required this.autoPlay,
    required this.autoInitialize,
    required this.loop,
    required this.muted,
    required this.volume,
    required this.playbackRate,
    required this.preload,
    required this.keepAlive,
    required this.preferHardwareDecoding,
    required this.enableAudio,
    required this.enableVideo,
    required this.enableSubtitles,
    required this.enableBuffering,
    required this.enableRecovery,
    required this.enableFallback,
    required this.enableMetrics,
    required this.enableDiagnostics,
    this.sourceId,
    required this.maxRecoveryAttempts,
    required this.maxFallbackAttempts,
  }) : super._();
  @override
  PlayerOptions rebuild(void Function(PlayerOptionsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlayerOptionsBuilder toBuilder() => PlayerOptionsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerOptions &&
        autoPlay == other.autoPlay &&
        autoInitialize == other.autoInitialize &&
        loop == other.loop &&
        muted == other.muted &&
        volume == other.volume &&
        playbackRate == other.playbackRate &&
        preload == other.preload &&
        keepAlive == other.keepAlive &&
        preferHardwareDecoding == other.preferHardwareDecoding &&
        enableAudio == other.enableAudio &&
        enableVideo == other.enableVideo &&
        enableSubtitles == other.enableSubtitles &&
        enableBuffering == other.enableBuffering &&
        enableRecovery == other.enableRecovery &&
        enableFallback == other.enableFallback &&
        enableMetrics == other.enableMetrics &&
        enableDiagnostics == other.enableDiagnostics &&
        sourceId == other.sourceId &&
        maxRecoveryAttempts == other.maxRecoveryAttempts &&
        maxFallbackAttempts == other.maxFallbackAttempts;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, autoPlay.hashCode);
    _$hash = $jc(_$hash, autoInitialize.hashCode);
    _$hash = $jc(_$hash, loop.hashCode);
    _$hash = $jc(_$hash, muted.hashCode);
    _$hash = $jc(_$hash, volume.hashCode);
    _$hash = $jc(_$hash, playbackRate.hashCode);
    _$hash = $jc(_$hash, preload.hashCode);
    _$hash = $jc(_$hash, keepAlive.hashCode);
    _$hash = $jc(_$hash, preferHardwareDecoding.hashCode);
    _$hash = $jc(_$hash, enableAudio.hashCode);
    _$hash = $jc(_$hash, enableVideo.hashCode);
    _$hash = $jc(_$hash, enableSubtitles.hashCode);
    _$hash = $jc(_$hash, enableBuffering.hashCode);
    _$hash = $jc(_$hash, enableRecovery.hashCode);
    _$hash = $jc(_$hash, enableFallback.hashCode);
    _$hash = $jc(_$hash, enableMetrics.hashCode);
    _$hash = $jc(_$hash, enableDiagnostics.hashCode);
    _$hash = $jc(_$hash, sourceId.hashCode);
    _$hash = $jc(_$hash, maxRecoveryAttempts.hashCode);
    _$hash = $jc(_$hash, maxFallbackAttempts.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerOptions')
          ..add('autoPlay', autoPlay)
          ..add('autoInitialize', autoInitialize)
          ..add('loop', loop)
          ..add('muted', muted)
          ..add('volume', volume)
          ..add('playbackRate', playbackRate)
          ..add('preload', preload)
          ..add('keepAlive', keepAlive)
          ..add('preferHardwareDecoding', preferHardwareDecoding)
          ..add('enableAudio', enableAudio)
          ..add('enableVideo', enableVideo)
          ..add('enableSubtitles', enableSubtitles)
          ..add('enableBuffering', enableBuffering)
          ..add('enableRecovery', enableRecovery)
          ..add('enableFallback', enableFallback)
          ..add('enableMetrics', enableMetrics)
          ..add('enableDiagnostics', enableDiagnostics)
          ..add('sourceId', sourceId)
          ..add('maxRecoveryAttempts', maxRecoveryAttempts)
          ..add('maxFallbackAttempts', maxFallbackAttempts))
        .toString();
  }
}

class PlayerOptionsBuilder
    implements Builder<PlayerOptions, PlayerOptionsBuilder> {
  _$PlayerOptions? _$v;

  bool? _autoPlay;
  bool? get autoPlay => _$this._autoPlay;
  set autoPlay(bool? autoPlay) => _$this._autoPlay = autoPlay;

  bool? _autoInitialize;
  bool? get autoInitialize => _$this._autoInitialize;
  set autoInitialize(bool? autoInitialize) =>
      _$this._autoInitialize = autoInitialize;

  bool? _loop;
  bool? get loop => _$this._loop;
  set loop(bool? loop) => _$this._loop = loop;

  bool? _muted;
  bool? get muted => _$this._muted;
  set muted(bool? muted) => _$this._muted = muted;

  double? _volume;
  double? get volume => _$this._volume;
  set volume(double? volume) => _$this._volume = volume;

  double? _playbackRate;
  double? get playbackRate => _$this._playbackRate;
  set playbackRate(double? playbackRate) => _$this._playbackRate = playbackRate;

  bool? _preload;
  bool? get preload => _$this._preload;
  set preload(bool? preload) => _$this._preload = preload;

  bool? _keepAlive;
  bool? get keepAlive => _$this._keepAlive;
  set keepAlive(bool? keepAlive) => _$this._keepAlive = keepAlive;

  bool? _preferHardwareDecoding;
  bool? get preferHardwareDecoding => _$this._preferHardwareDecoding;
  set preferHardwareDecoding(bool? preferHardwareDecoding) =>
      _$this._preferHardwareDecoding = preferHardwareDecoding;

  bool? _enableAudio;
  bool? get enableAudio => _$this._enableAudio;
  set enableAudio(bool? enableAudio) => _$this._enableAudio = enableAudio;

  bool? _enableVideo;
  bool? get enableVideo => _$this._enableVideo;
  set enableVideo(bool? enableVideo) => _$this._enableVideo = enableVideo;

  bool? _enableSubtitles;
  bool? get enableSubtitles => _$this._enableSubtitles;
  set enableSubtitles(bool? enableSubtitles) =>
      _$this._enableSubtitles = enableSubtitles;

  bool? _enableBuffering;
  bool? get enableBuffering => _$this._enableBuffering;
  set enableBuffering(bool? enableBuffering) =>
      _$this._enableBuffering = enableBuffering;

  bool? _enableRecovery;
  bool? get enableRecovery => _$this._enableRecovery;
  set enableRecovery(bool? enableRecovery) =>
      _$this._enableRecovery = enableRecovery;

  bool? _enableFallback;
  bool? get enableFallback => _$this._enableFallback;
  set enableFallback(bool? enableFallback) =>
      _$this._enableFallback = enableFallback;

  bool? _enableMetrics;
  bool? get enableMetrics => _$this._enableMetrics;
  set enableMetrics(bool? enableMetrics) =>
      _$this._enableMetrics = enableMetrics;

  bool? _enableDiagnostics;
  bool? get enableDiagnostics => _$this._enableDiagnostics;
  set enableDiagnostics(bool? enableDiagnostics) =>
      _$this._enableDiagnostics = enableDiagnostics;

  SourceId? _sourceId;
  SourceId? get sourceId => _$this._sourceId;
  set sourceId(SourceId? sourceId) => _$this._sourceId = sourceId;

  int? _maxRecoveryAttempts;
  int? get maxRecoveryAttempts => _$this._maxRecoveryAttempts;
  set maxRecoveryAttempts(int? maxRecoveryAttempts) =>
      _$this._maxRecoveryAttempts = maxRecoveryAttempts;

  int? _maxFallbackAttempts;
  int? get maxFallbackAttempts => _$this._maxFallbackAttempts;
  set maxFallbackAttempts(int? maxFallbackAttempts) =>
      _$this._maxFallbackAttempts = maxFallbackAttempts;

  PlayerOptionsBuilder() {
    PlayerOptions._initialize(this);
  }

  PlayerOptionsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _autoPlay = $v.autoPlay;
      _autoInitialize = $v.autoInitialize;
      _loop = $v.loop;
      _muted = $v.muted;
      _volume = $v.volume;
      _playbackRate = $v.playbackRate;
      _preload = $v.preload;
      _keepAlive = $v.keepAlive;
      _preferHardwareDecoding = $v.preferHardwareDecoding;
      _enableAudio = $v.enableAudio;
      _enableVideo = $v.enableVideo;
      _enableSubtitles = $v.enableSubtitles;
      _enableBuffering = $v.enableBuffering;
      _enableRecovery = $v.enableRecovery;
      _enableFallback = $v.enableFallback;
      _enableMetrics = $v.enableMetrics;
      _enableDiagnostics = $v.enableDiagnostics;
      _sourceId = $v.sourceId;
      _maxRecoveryAttempts = $v.maxRecoveryAttempts;
      _maxFallbackAttempts = $v.maxFallbackAttempts;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerOptions other) {
    _$v = other as _$PlayerOptions;
  }

  @override
  void update(void Function(PlayerOptionsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerOptions build() => _build();

  _$PlayerOptions _build() {
    PlayerOptions._validate(this);
    final _$result =
        _$v ??
        _$PlayerOptions._(
          autoPlay: BuiltValueNullFieldError.checkNotNull(
            autoPlay,
            r'PlayerOptions',
            'autoPlay',
          ),
          autoInitialize: BuiltValueNullFieldError.checkNotNull(
            autoInitialize,
            r'PlayerOptions',
            'autoInitialize',
          ),
          loop: BuiltValueNullFieldError.checkNotNull(
            loop,
            r'PlayerOptions',
            'loop',
          ),
          muted: BuiltValueNullFieldError.checkNotNull(
            muted,
            r'PlayerOptions',
            'muted',
          ),
          volume: BuiltValueNullFieldError.checkNotNull(
            volume,
            r'PlayerOptions',
            'volume',
          ),
          playbackRate: BuiltValueNullFieldError.checkNotNull(
            playbackRate,
            r'PlayerOptions',
            'playbackRate',
          ),
          preload: BuiltValueNullFieldError.checkNotNull(
            preload,
            r'PlayerOptions',
            'preload',
          ),
          keepAlive: BuiltValueNullFieldError.checkNotNull(
            keepAlive,
            r'PlayerOptions',
            'keepAlive',
          ),
          preferHardwareDecoding: BuiltValueNullFieldError.checkNotNull(
            preferHardwareDecoding,
            r'PlayerOptions',
            'preferHardwareDecoding',
          ),
          enableAudio: BuiltValueNullFieldError.checkNotNull(
            enableAudio,
            r'PlayerOptions',
            'enableAudio',
          ),
          enableVideo: BuiltValueNullFieldError.checkNotNull(
            enableVideo,
            r'PlayerOptions',
            'enableVideo',
          ),
          enableSubtitles: BuiltValueNullFieldError.checkNotNull(
            enableSubtitles,
            r'PlayerOptions',
            'enableSubtitles',
          ),
          enableBuffering: BuiltValueNullFieldError.checkNotNull(
            enableBuffering,
            r'PlayerOptions',
            'enableBuffering',
          ),
          enableRecovery: BuiltValueNullFieldError.checkNotNull(
            enableRecovery,
            r'PlayerOptions',
            'enableRecovery',
          ),
          enableFallback: BuiltValueNullFieldError.checkNotNull(
            enableFallback,
            r'PlayerOptions',
            'enableFallback',
          ),
          enableMetrics: BuiltValueNullFieldError.checkNotNull(
            enableMetrics,
            r'PlayerOptions',
            'enableMetrics',
          ),
          enableDiagnostics: BuiltValueNullFieldError.checkNotNull(
            enableDiagnostics,
            r'PlayerOptions',
            'enableDiagnostics',
          ),
          sourceId: sourceId,
          maxRecoveryAttempts: BuiltValueNullFieldError.checkNotNull(
            maxRecoveryAttempts,
            r'PlayerOptions',
            'maxRecoveryAttempts',
          ),
          maxFallbackAttempts: BuiltValueNullFieldError.checkNotNull(
            maxFallbackAttempts,
            r'PlayerOptions',
            'maxFallbackAttempts',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
