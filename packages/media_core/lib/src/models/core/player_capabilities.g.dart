// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_capabilities.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerCapabilities extends PlayerCapabilities {
  @override
  final bool play;
  @override
  final bool pause;
  @override
  final bool stop;
  @override
  final bool seek;
  @override
  final bool setVolume;
  @override
  final bool setPlaybackSpeed;
  @override
  final bool setLooping;
  @override
  final bool setMuted;
  @override
  final bool fullscreen;
  @override
  final bool pictureInPicture;
  @override
  final bool backgroundPlayback;
  @override
  final bool frameStep;
  @override
  final bool snapshot;

  factory _$PlayerCapabilities([
    void Function(PlayerCapabilitiesBuilder)? updates,
  ]) => (PlayerCapabilitiesBuilder()..update(updates))._build();

  _$PlayerCapabilities._({
    required this.play,
    required this.pause,
    required this.stop,
    required this.seek,
    required this.setVolume,
    required this.setPlaybackSpeed,
    required this.setLooping,
    required this.setMuted,
    required this.fullscreen,
    required this.pictureInPicture,
    required this.backgroundPlayback,
    required this.frameStep,
    required this.snapshot,
  }) : super._();
  @override
  PlayerCapabilities rebuild(
    void Function(PlayerCapabilitiesBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PlayerCapabilitiesBuilder toBuilder() =>
      PlayerCapabilitiesBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerCapabilities &&
        play == other.play &&
        pause == other.pause &&
        stop == other.stop &&
        seek == other.seek &&
        setVolume == other.setVolume &&
        setPlaybackSpeed == other.setPlaybackSpeed &&
        setLooping == other.setLooping &&
        setMuted == other.setMuted &&
        fullscreen == other.fullscreen &&
        pictureInPicture == other.pictureInPicture &&
        backgroundPlayback == other.backgroundPlayback &&
        frameStep == other.frameStep &&
        snapshot == other.snapshot;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, play.hashCode);
    _$hash = $jc(_$hash, pause.hashCode);
    _$hash = $jc(_$hash, stop.hashCode);
    _$hash = $jc(_$hash, seek.hashCode);
    _$hash = $jc(_$hash, setVolume.hashCode);
    _$hash = $jc(_$hash, setPlaybackSpeed.hashCode);
    _$hash = $jc(_$hash, setLooping.hashCode);
    _$hash = $jc(_$hash, setMuted.hashCode);
    _$hash = $jc(_$hash, fullscreen.hashCode);
    _$hash = $jc(_$hash, pictureInPicture.hashCode);
    _$hash = $jc(_$hash, backgroundPlayback.hashCode);
    _$hash = $jc(_$hash, frameStep.hashCode);
    _$hash = $jc(_$hash, snapshot.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerCapabilities')
          ..add('play', play)
          ..add('pause', pause)
          ..add('stop', stop)
          ..add('seek', seek)
          ..add('setVolume', setVolume)
          ..add('setPlaybackSpeed', setPlaybackSpeed)
          ..add('setLooping', setLooping)
          ..add('setMuted', setMuted)
          ..add('fullscreen', fullscreen)
          ..add('pictureInPicture', pictureInPicture)
          ..add('backgroundPlayback', backgroundPlayback)
          ..add('frameStep', frameStep)
          ..add('snapshot', snapshot))
        .toString();
  }
}

class PlayerCapabilitiesBuilder
    implements Builder<PlayerCapabilities, PlayerCapabilitiesBuilder> {
  _$PlayerCapabilities? _$v;

  bool? _play;
  bool? get play => _$this._play;
  set play(bool? play) => _$this._play = play;

  bool? _pause;
  bool? get pause => _$this._pause;
  set pause(bool? pause) => _$this._pause = pause;

  bool? _stop;
  bool? get stop => _$this._stop;
  set stop(bool? stop) => _$this._stop = stop;

  bool? _seek;
  bool? get seek => _$this._seek;
  set seek(bool? seek) => _$this._seek = seek;

  bool? _setVolume;
  bool? get setVolume => _$this._setVolume;
  set setVolume(bool? setVolume) => _$this._setVolume = setVolume;

  bool? _setPlaybackSpeed;
  bool? get setPlaybackSpeed => _$this._setPlaybackSpeed;
  set setPlaybackSpeed(bool? setPlaybackSpeed) =>
      _$this._setPlaybackSpeed = setPlaybackSpeed;

  bool? _setLooping;
  bool? get setLooping => _$this._setLooping;
  set setLooping(bool? setLooping) => _$this._setLooping = setLooping;

  bool? _setMuted;
  bool? get setMuted => _$this._setMuted;
  set setMuted(bool? setMuted) => _$this._setMuted = setMuted;

  bool? _fullscreen;
  bool? get fullscreen => _$this._fullscreen;
  set fullscreen(bool? fullscreen) => _$this._fullscreen = fullscreen;

  bool? _pictureInPicture;
  bool? get pictureInPicture => _$this._pictureInPicture;
  set pictureInPicture(bool? pictureInPicture) =>
      _$this._pictureInPicture = pictureInPicture;

  bool? _backgroundPlayback;
  bool? get backgroundPlayback => _$this._backgroundPlayback;
  set backgroundPlayback(bool? backgroundPlayback) =>
      _$this._backgroundPlayback = backgroundPlayback;

  bool? _frameStep;
  bool? get frameStep => _$this._frameStep;
  set frameStep(bool? frameStep) => _$this._frameStep = frameStep;

  bool? _snapshot;
  bool? get snapshot => _$this._snapshot;
  set snapshot(bool? snapshot) => _$this._snapshot = snapshot;

  PlayerCapabilitiesBuilder() {
    PlayerCapabilities._initialize(this);
  }

  PlayerCapabilitiesBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _play = $v.play;
      _pause = $v.pause;
      _stop = $v.stop;
      _seek = $v.seek;
      _setVolume = $v.setVolume;
      _setPlaybackSpeed = $v.setPlaybackSpeed;
      _setLooping = $v.setLooping;
      _setMuted = $v.setMuted;
      _fullscreen = $v.fullscreen;
      _pictureInPicture = $v.pictureInPicture;
      _backgroundPlayback = $v.backgroundPlayback;
      _frameStep = $v.frameStep;
      _snapshot = $v.snapshot;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerCapabilities other) {
    _$v = other as _$PlayerCapabilities;
  }

  @override
  void update(void Function(PlayerCapabilitiesBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerCapabilities build() => _build();

  _$PlayerCapabilities _build() {
    final _$result =
        _$v ??
        _$PlayerCapabilities._(
          play: BuiltValueNullFieldError.checkNotNull(
            play,
            r'PlayerCapabilities',
            'play',
          ),
          pause: BuiltValueNullFieldError.checkNotNull(
            pause,
            r'PlayerCapabilities',
            'pause',
          ),
          stop: BuiltValueNullFieldError.checkNotNull(
            stop,
            r'PlayerCapabilities',
            'stop',
          ),
          seek: BuiltValueNullFieldError.checkNotNull(
            seek,
            r'PlayerCapabilities',
            'seek',
          ),
          setVolume: BuiltValueNullFieldError.checkNotNull(
            setVolume,
            r'PlayerCapabilities',
            'setVolume',
          ),
          setPlaybackSpeed: BuiltValueNullFieldError.checkNotNull(
            setPlaybackSpeed,
            r'PlayerCapabilities',
            'setPlaybackSpeed',
          ),
          setLooping: BuiltValueNullFieldError.checkNotNull(
            setLooping,
            r'PlayerCapabilities',
            'setLooping',
          ),
          setMuted: BuiltValueNullFieldError.checkNotNull(
            setMuted,
            r'PlayerCapabilities',
            'setMuted',
          ),
          fullscreen: BuiltValueNullFieldError.checkNotNull(
            fullscreen,
            r'PlayerCapabilities',
            'fullscreen',
          ),
          pictureInPicture: BuiltValueNullFieldError.checkNotNull(
            pictureInPicture,
            r'PlayerCapabilities',
            'pictureInPicture',
          ),
          backgroundPlayback: BuiltValueNullFieldError.checkNotNull(
            backgroundPlayback,
            r'PlayerCapabilities',
            'backgroundPlayback',
          ),
          frameStep: BuiltValueNullFieldError.checkNotNull(
            frameStep,
            r'PlayerCapabilities',
            'frameStep',
          ),
          snapshot: BuiltValueNullFieldError.checkNotNull(
            snapshot,
            r'PlayerCapabilities',
            'snapshot',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
