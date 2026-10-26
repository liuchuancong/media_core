// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_adapter_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerAdapterState extends PlayerAdapterState {
  @override
  final bool initialized;
  @override
  final bool opened;
  @override
  final bool playing;
  @override
  final bool paused;
  @override
  final bool buffering;
  @override
  final bool completed;
  @override
  final bool hasError;
  @override
  final Duration position;
  @override
  final Duration? duration;
  @override
  final double volume;
  @override
  final double rate;
  @override
  final int? width;
  @override
  final int? height;
  @override
  final String? errorMessage;

  factory _$PlayerAdapterState([
    void Function(PlayerAdapterStateBuilder)? updates,
  ]) => (PlayerAdapterStateBuilder()..update(updates))._build();

  _$PlayerAdapterState._({
    required this.initialized,
    required this.opened,
    required this.playing,
    required this.paused,
    required this.buffering,
    required this.completed,
    required this.hasError,
    required this.position,
    this.duration,
    required this.volume,
    required this.rate,
    this.width,
    this.height,
    this.errorMessage,
  }) : super._();
  @override
  PlayerAdapterState rebuild(
    void Function(PlayerAdapterStateBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PlayerAdapterStateBuilder toBuilder() =>
      PlayerAdapterStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerAdapterState &&
        initialized == other.initialized &&
        opened == other.opened &&
        playing == other.playing &&
        paused == other.paused &&
        buffering == other.buffering &&
        completed == other.completed &&
        hasError == other.hasError &&
        position == other.position &&
        duration == other.duration &&
        volume == other.volume &&
        rate == other.rate &&
        width == other.width &&
        height == other.height &&
        errorMessage == other.errorMessage;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, initialized.hashCode);
    _$hash = $jc(_$hash, opened.hashCode);
    _$hash = $jc(_$hash, playing.hashCode);
    _$hash = $jc(_$hash, paused.hashCode);
    _$hash = $jc(_$hash, buffering.hashCode);
    _$hash = $jc(_$hash, completed.hashCode);
    _$hash = $jc(_$hash, hasError.hashCode);
    _$hash = $jc(_$hash, position.hashCode);
    _$hash = $jc(_$hash, duration.hashCode);
    _$hash = $jc(_$hash, volume.hashCode);
    _$hash = $jc(_$hash, rate.hashCode);
    _$hash = $jc(_$hash, width.hashCode);
    _$hash = $jc(_$hash, height.hashCode);
    _$hash = $jc(_$hash, errorMessage.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerAdapterState')
          ..add('initialized', initialized)
          ..add('opened', opened)
          ..add('playing', playing)
          ..add('paused', paused)
          ..add('buffering', buffering)
          ..add('completed', completed)
          ..add('hasError', hasError)
          ..add('position', position)
          ..add('duration', duration)
          ..add('volume', volume)
          ..add('rate', rate)
          ..add('width', width)
          ..add('height', height)
          ..add('errorMessage', errorMessage))
        .toString();
  }
}

class PlayerAdapterStateBuilder
    implements Builder<PlayerAdapterState, PlayerAdapterStateBuilder> {
  _$PlayerAdapterState? _$v;

  bool? _initialized;
  bool? get initialized => _$this._initialized;
  set initialized(bool? initialized) => _$this._initialized = initialized;

  bool? _opened;
  bool? get opened => _$this._opened;
  set opened(bool? opened) => _$this._opened = opened;

  bool? _playing;
  bool? get playing => _$this._playing;
  set playing(bool? playing) => _$this._playing = playing;

  bool? _paused;
  bool? get paused => _$this._paused;
  set paused(bool? paused) => _$this._paused = paused;

  bool? _buffering;
  bool? get buffering => _$this._buffering;
  set buffering(bool? buffering) => _$this._buffering = buffering;

  bool? _completed;
  bool? get completed => _$this._completed;
  set completed(bool? completed) => _$this._completed = completed;

  bool? _hasError;
  bool? get hasError => _$this._hasError;
  set hasError(bool? hasError) => _$this._hasError = hasError;

  Duration? _position;
  Duration? get position => _$this._position;
  set position(Duration? position) => _$this._position = position;

  Duration? _duration;
  Duration? get duration => _$this._duration;
  set duration(Duration? duration) => _$this._duration = duration;

  double? _volume;
  double? get volume => _$this._volume;
  set volume(double? volume) => _$this._volume = volume;

  double? _rate;
  double? get rate => _$this._rate;
  set rate(double? rate) => _$this._rate = rate;

  int? _width;
  int? get width => _$this._width;
  set width(int? width) => _$this._width = width;

  int? _height;
  int? get height => _$this._height;
  set height(int? height) => _$this._height = height;

  String? _errorMessage;
  String? get errorMessage => _$this._errorMessage;
  set errorMessage(String? errorMessage) => _$this._errorMessage = errorMessage;

  PlayerAdapterStateBuilder() {
    PlayerAdapterState._initialize(this);
  }

  PlayerAdapterStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _initialized = $v.initialized;
      _opened = $v.opened;
      _playing = $v.playing;
      _paused = $v.paused;
      _buffering = $v.buffering;
      _completed = $v.completed;
      _hasError = $v.hasError;
      _position = $v.position;
      _duration = $v.duration;
      _volume = $v.volume;
      _rate = $v.rate;
      _width = $v.width;
      _height = $v.height;
      _errorMessage = $v.errorMessage;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerAdapterState other) {
    _$v = other as _$PlayerAdapterState;
  }

  @override
  void update(void Function(PlayerAdapterStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerAdapterState build() => _build();

  _$PlayerAdapterState _build() {
    final _$result =
        _$v ??
        _$PlayerAdapterState._(
          initialized: BuiltValueNullFieldError.checkNotNull(
            initialized,
            r'PlayerAdapterState',
            'initialized',
          ),
          opened: BuiltValueNullFieldError.checkNotNull(
            opened,
            r'PlayerAdapterState',
            'opened',
          ),
          playing: BuiltValueNullFieldError.checkNotNull(
            playing,
            r'PlayerAdapterState',
            'playing',
          ),
          paused: BuiltValueNullFieldError.checkNotNull(
            paused,
            r'PlayerAdapterState',
            'paused',
          ),
          buffering: BuiltValueNullFieldError.checkNotNull(
            buffering,
            r'PlayerAdapterState',
            'buffering',
          ),
          completed: BuiltValueNullFieldError.checkNotNull(
            completed,
            r'PlayerAdapterState',
            'completed',
          ),
          hasError: BuiltValueNullFieldError.checkNotNull(
            hasError,
            r'PlayerAdapterState',
            'hasError',
          ),
          position: BuiltValueNullFieldError.checkNotNull(
            position,
            r'PlayerAdapterState',
            'position',
          ),
          duration: duration,
          volume: BuiltValueNullFieldError.checkNotNull(
            volume,
            r'PlayerAdapterState',
            'volume',
          ),
          rate: BuiltValueNullFieldError.checkNotNull(
            rate,
            r'PlayerAdapterState',
            'rate',
          ),
          width: width,
          height: height,
          errorMessage: errorMessage,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
