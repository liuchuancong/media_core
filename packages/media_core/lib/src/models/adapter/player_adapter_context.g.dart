// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_adapter_context.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerAdapterContext extends PlayerAdapterContext {
  @override
  final PlayerId playerId;
  @override
  final SessionId sessionId;
  @override
  final PlayerAdapterConfig config;
  @override
  final PlayerConfig? playerConfig;
  @override
  final Map<String, Object?> options;
  @override
  final PlatformCapabilities platform;
  @override
  final PlatformDeviceProfile device;
  @override
  final PlatformCodecCapabilities codecs;
  @override
  final bool debug;

  factory _$PlayerAdapterContext([
    void Function(PlayerAdapterContextBuilder)? updates,
  ]) => (PlayerAdapterContextBuilder()..update(updates))._build();

  _$PlayerAdapterContext._({
    required this.playerId,
    required this.sessionId,
    required this.config,
    this.playerConfig,
    required this.options,
    required this.platform,
    required this.device,
    required this.codecs,
    required this.debug,
  }) : super._();
  @override
  PlayerAdapterContext rebuild(
    void Function(PlayerAdapterContextBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PlayerAdapterContextBuilder toBuilder() =>
      PlayerAdapterContextBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerAdapterContext &&
        playerId == other.playerId &&
        sessionId == other.sessionId &&
        config == other.config &&
        playerConfig == other.playerConfig &&
        options == other.options &&
        platform == other.platform &&
        device == other.device &&
        codecs == other.codecs &&
        debug == other.debug;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, playerId.hashCode);
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jc(_$hash, config.hashCode);
    _$hash = $jc(_$hash, playerConfig.hashCode);
    _$hash = $jc(_$hash, options.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, device.hashCode);
    _$hash = $jc(_$hash, codecs.hashCode);
    _$hash = $jc(_$hash, debug.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerAdapterContext')
          ..add('playerId', playerId)
          ..add('sessionId', sessionId)
          ..add('config', config)
          ..add('playerConfig', playerConfig)
          ..add('options', options)
          ..add('platform', platform)
          ..add('device', device)
          ..add('codecs', codecs)
          ..add('debug', debug))
        .toString();
  }
}

class PlayerAdapterContextBuilder
    implements Builder<PlayerAdapterContext, PlayerAdapterContextBuilder> {
  _$PlayerAdapterContext? _$v;

  PlayerId? _playerId;
  PlayerId? get playerId => _$this._playerId;
  set playerId(PlayerId? playerId) => _$this._playerId = playerId;

  SessionId? _sessionId;
  SessionId? get sessionId => _$this._sessionId;
  set sessionId(SessionId? sessionId) => _$this._sessionId = sessionId;

  PlayerAdapterConfigBuilder? _config;
  PlayerAdapterConfigBuilder get config =>
      _$this._config ??= PlayerAdapterConfigBuilder();
  set config(PlayerAdapterConfigBuilder? config) => _$this._config = config;

  PlayerConfig? _playerConfig;
  PlayerConfig? get playerConfig => _$this._playerConfig;
  set playerConfig(PlayerConfig? playerConfig) =>
      _$this._playerConfig = playerConfig;

  Map<String, Object?>? _options;
  Map<String, Object?>? get options => _$this._options;
  set options(Map<String, Object?>? options) => _$this._options = options;

  PlatformCapabilities? _platform;
  PlatformCapabilities? get platform => _$this._platform;
  set platform(PlatformCapabilities? platform) => _$this._platform = platform;

  PlatformDeviceProfile? _device;
  PlatformDeviceProfile? get device => _$this._device;
  set device(PlatformDeviceProfile? device) => _$this._device = device;

  PlatformCodecCapabilities? _codecs;
  PlatformCodecCapabilities? get codecs => _$this._codecs;
  set codecs(PlatformCodecCapabilities? codecs) => _$this._codecs = codecs;

  bool? _debug;
  bool? get debug => _$this._debug;
  set debug(bool? debug) => _$this._debug = debug;

  PlayerAdapterContextBuilder() {
    PlayerAdapterContext._initialize(this);
  }

  PlayerAdapterContextBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _playerId = $v.playerId;
      _sessionId = $v.sessionId;
      _config = $v.config.toBuilder();
      _playerConfig = $v.playerConfig;
      _options = $v.options;
      _platform = $v.platform;
      _device = $v.device;
      _codecs = $v.codecs;
      _debug = $v.debug;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerAdapterContext other) {
    _$v = other as _$PlayerAdapterContext;
  }

  @override
  void update(void Function(PlayerAdapterContextBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerAdapterContext build() => _build();

  _$PlayerAdapterContext _build() {
    _$PlayerAdapterContext _$result;
    try {
      _$result =
          _$v ??
          _$PlayerAdapterContext._(
            playerId: BuiltValueNullFieldError.checkNotNull(
              playerId,
              r'PlayerAdapterContext',
              'playerId',
            ),
            sessionId: BuiltValueNullFieldError.checkNotNull(
              sessionId,
              r'PlayerAdapterContext',
              'sessionId',
            ),
            config: config.build(),
            playerConfig: playerConfig,
            options: BuiltValueNullFieldError.checkNotNull(
              options,
              r'PlayerAdapterContext',
              'options',
            ),
            platform: BuiltValueNullFieldError.checkNotNull(
              platform,
              r'PlayerAdapterContext',
              'platform',
            ),
            device: BuiltValueNullFieldError.checkNotNull(
              device,
              r'PlayerAdapterContext',
              'device',
            ),
            codecs: BuiltValueNullFieldError.checkNotNull(
              codecs,
              r'PlayerAdapterContext',
              'codecs',
            ),
            debug: BuiltValueNullFieldError.checkNotNull(
              debug,
              r'PlayerAdapterContext',
              'debug',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'config';
        config.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PlayerAdapterContext',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
