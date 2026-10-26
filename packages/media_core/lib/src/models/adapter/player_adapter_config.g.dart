// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_adapter_config.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerAdapterConfig extends PlayerAdapterConfig {
  @override
  final bool hardwareAcceleration;
  @override
  final bool audioEnabled;
  @override
  final double volume;
  @override
  final double playbackRate;
  @override
  final Duration networkTimeout;
  @override
  final Duration bufferDuration;
  @override
  final int? maxBufferBytes;
  @override
  final String? preferredDecoder;
  @override
  final Map<String, Object?> options;

  factory _$PlayerAdapterConfig([
    void Function(PlayerAdapterConfigBuilder)? updates,
  ]) => (PlayerAdapterConfigBuilder()..update(updates))._build();

  _$PlayerAdapterConfig._({
    required this.hardwareAcceleration,
    required this.audioEnabled,
    required this.volume,
    required this.playbackRate,
    required this.networkTimeout,
    required this.bufferDuration,
    this.maxBufferBytes,
    this.preferredDecoder,
    required this.options,
  }) : super._();
  @override
  PlayerAdapterConfig rebuild(
    void Function(PlayerAdapterConfigBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PlayerAdapterConfigBuilder toBuilder() =>
      PlayerAdapterConfigBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerAdapterConfig &&
        hardwareAcceleration == other.hardwareAcceleration &&
        audioEnabled == other.audioEnabled &&
        volume == other.volume &&
        playbackRate == other.playbackRate &&
        networkTimeout == other.networkTimeout &&
        bufferDuration == other.bufferDuration &&
        maxBufferBytes == other.maxBufferBytes &&
        preferredDecoder == other.preferredDecoder &&
        options == other.options;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, hardwareAcceleration.hashCode);
    _$hash = $jc(_$hash, audioEnabled.hashCode);
    _$hash = $jc(_$hash, volume.hashCode);
    _$hash = $jc(_$hash, playbackRate.hashCode);
    _$hash = $jc(_$hash, networkTimeout.hashCode);
    _$hash = $jc(_$hash, bufferDuration.hashCode);
    _$hash = $jc(_$hash, maxBufferBytes.hashCode);
    _$hash = $jc(_$hash, preferredDecoder.hashCode);
    _$hash = $jc(_$hash, options.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerAdapterConfig')
          ..add('hardwareAcceleration', hardwareAcceleration)
          ..add('audioEnabled', audioEnabled)
          ..add('volume', volume)
          ..add('playbackRate', playbackRate)
          ..add('networkTimeout', networkTimeout)
          ..add('bufferDuration', bufferDuration)
          ..add('maxBufferBytes', maxBufferBytes)
          ..add('preferredDecoder', preferredDecoder)
          ..add('options', options))
        .toString();
  }
}

class PlayerAdapterConfigBuilder
    implements Builder<PlayerAdapterConfig, PlayerAdapterConfigBuilder> {
  _$PlayerAdapterConfig? _$v;

  bool? _hardwareAcceleration;
  bool? get hardwareAcceleration => _$this._hardwareAcceleration;
  set hardwareAcceleration(bool? hardwareAcceleration) =>
      _$this._hardwareAcceleration = hardwareAcceleration;

  bool? _audioEnabled;
  bool? get audioEnabled => _$this._audioEnabled;
  set audioEnabled(bool? audioEnabled) => _$this._audioEnabled = audioEnabled;

  double? _volume;
  double? get volume => _$this._volume;
  set volume(double? volume) => _$this._volume = volume;

  double? _playbackRate;
  double? get playbackRate => _$this._playbackRate;
  set playbackRate(double? playbackRate) => _$this._playbackRate = playbackRate;

  Duration? _networkTimeout;
  Duration? get networkTimeout => _$this._networkTimeout;
  set networkTimeout(Duration? networkTimeout) =>
      _$this._networkTimeout = networkTimeout;

  Duration? _bufferDuration;
  Duration? get bufferDuration => _$this._bufferDuration;
  set bufferDuration(Duration? bufferDuration) =>
      _$this._bufferDuration = bufferDuration;

  int? _maxBufferBytes;
  int? get maxBufferBytes => _$this._maxBufferBytes;
  set maxBufferBytes(int? maxBufferBytes) =>
      _$this._maxBufferBytes = maxBufferBytes;

  String? _preferredDecoder;
  String? get preferredDecoder => _$this._preferredDecoder;
  set preferredDecoder(String? preferredDecoder) =>
      _$this._preferredDecoder = preferredDecoder;

  Map<String, Object?>? _options;
  Map<String, Object?>? get options => _$this._options;
  set options(Map<String, Object?>? options) => _$this._options = options;

  PlayerAdapterConfigBuilder() {
    PlayerAdapterConfig._initialize(this);
  }

  PlayerAdapterConfigBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _hardwareAcceleration = $v.hardwareAcceleration;
      _audioEnabled = $v.audioEnabled;
      _volume = $v.volume;
      _playbackRate = $v.playbackRate;
      _networkTimeout = $v.networkTimeout;
      _bufferDuration = $v.bufferDuration;
      _maxBufferBytes = $v.maxBufferBytes;
      _preferredDecoder = $v.preferredDecoder;
      _options = $v.options;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerAdapterConfig other) {
    _$v = other as _$PlayerAdapterConfig;
  }

  @override
  void update(void Function(PlayerAdapterConfigBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerAdapterConfig build() => _build();

  _$PlayerAdapterConfig _build() {
    final _$result =
        _$v ??
        _$PlayerAdapterConfig._(
          hardwareAcceleration: BuiltValueNullFieldError.checkNotNull(
            hardwareAcceleration,
            r'PlayerAdapterConfig',
            'hardwareAcceleration',
          ),
          audioEnabled: BuiltValueNullFieldError.checkNotNull(
            audioEnabled,
            r'PlayerAdapterConfig',
            'audioEnabled',
          ),
          volume: BuiltValueNullFieldError.checkNotNull(
            volume,
            r'PlayerAdapterConfig',
            'volume',
          ),
          playbackRate: BuiltValueNullFieldError.checkNotNull(
            playbackRate,
            r'PlayerAdapterConfig',
            'playbackRate',
          ),
          networkTimeout: BuiltValueNullFieldError.checkNotNull(
            networkTimeout,
            r'PlayerAdapterConfig',
            'networkTimeout',
          ),
          bufferDuration: BuiltValueNullFieldError.checkNotNull(
            bufferDuration,
            r'PlayerAdapterConfig',
            'bufferDuration',
          ),
          maxBufferBytes: maxBufferBytes,
          preferredDecoder: preferredDecoder,
          options: BuiltValueNullFieldError.checkNotNull(
            options,
            r'PlayerAdapterConfig',
            'options',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
