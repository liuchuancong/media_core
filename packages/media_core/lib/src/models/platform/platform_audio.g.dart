// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_audio.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlatformAudio extends PlatformAudio {
  @override
  final bool enabled;
  @override
  final bool output;
  @override
  final bool volumeControl;
  @override
  final bool muteControl;
  @override
  final bool audioFocus;
  @override
  final bool bluetooth;
  @override
  final bool speaker;
  @override
  final bool headphones;
  @override
  final int maxChannels;
  @override
  final List<int> sampleRates;

  factory _$PlatformAudio([void Function(PlatformAudioBuilder)? updates]) =>
      (PlatformAudioBuilder()..update(updates))._build();

  _$PlatformAudio._({
    required this.enabled,
    required this.output,
    required this.volumeControl,
    required this.muteControl,
    required this.audioFocus,
    required this.bluetooth,
    required this.speaker,
    required this.headphones,
    required this.maxChannels,
    required this.sampleRates,
  }) : super._();
  @override
  PlatformAudio rebuild(void Function(PlatformAudioBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlatformAudioBuilder toBuilder() => PlatformAudioBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlatformAudio &&
        enabled == other.enabled &&
        output == other.output &&
        volumeControl == other.volumeControl &&
        muteControl == other.muteControl &&
        audioFocus == other.audioFocus &&
        bluetooth == other.bluetooth &&
        speaker == other.speaker &&
        headphones == other.headphones &&
        maxChannels == other.maxChannels &&
        sampleRates == other.sampleRates;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, output.hashCode);
    _$hash = $jc(_$hash, volumeControl.hashCode);
    _$hash = $jc(_$hash, muteControl.hashCode);
    _$hash = $jc(_$hash, audioFocus.hashCode);
    _$hash = $jc(_$hash, bluetooth.hashCode);
    _$hash = $jc(_$hash, speaker.hashCode);
    _$hash = $jc(_$hash, headphones.hashCode);
    _$hash = $jc(_$hash, maxChannels.hashCode);
    _$hash = $jc(_$hash, sampleRates.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlatformAudio')
          ..add('enabled', enabled)
          ..add('output', output)
          ..add('volumeControl', volumeControl)
          ..add('muteControl', muteControl)
          ..add('audioFocus', audioFocus)
          ..add('bluetooth', bluetooth)
          ..add('speaker', speaker)
          ..add('headphones', headphones)
          ..add('maxChannels', maxChannels)
          ..add('sampleRates', sampleRates))
        .toString();
  }
}

class PlatformAudioBuilder
    implements Builder<PlatformAudio, PlatformAudioBuilder> {
  _$PlatformAudio? _$v;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  bool? _output;
  bool? get output => _$this._output;
  set output(bool? output) => _$this._output = output;

  bool? _volumeControl;
  bool? get volumeControl => _$this._volumeControl;
  set volumeControl(bool? volumeControl) =>
      _$this._volumeControl = volumeControl;

  bool? _muteControl;
  bool? get muteControl => _$this._muteControl;
  set muteControl(bool? muteControl) => _$this._muteControl = muteControl;

  bool? _audioFocus;
  bool? get audioFocus => _$this._audioFocus;
  set audioFocus(bool? audioFocus) => _$this._audioFocus = audioFocus;

  bool? _bluetooth;
  bool? get bluetooth => _$this._bluetooth;
  set bluetooth(bool? bluetooth) => _$this._bluetooth = bluetooth;

  bool? _speaker;
  bool? get speaker => _$this._speaker;
  set speaker(bool? speaker) => _$this._speaker = speaker;

  bool? _headphones;
  bool? get headphones => _$this._headphones;
  set headphones(bool? headphones) => _$this._headphones = headphones;

  int? _maxChannels;
  int? get maxChannels => _$this._maxChannels;
  set maxChannels(int? maxChannels) => _$this._maxChannels = maxChannels;

  List<int>? _sampleRates;
  List<int>? get sampleRates => _$this._sampleRates;
  set sampleRates(List<int>? sampleRates) => _$this._sampleRates = sampleRates;

  PlatformAudioBuilder() {
    PlatformAudio._initialize(this);
  }

  PlatformAudioBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _enabled = $v.enabled;
      _output = $v.output;
      _volumeControl = $v.volumeControl;
      _muteControl = $v.muteControl;
      _audioFocus = $v.audioFocus;
      _bluetooth = $v.bluetooth;
      _speaker = $v.speaker;
      _headphones = $v.headphones;
      _maxChannels = $v.maxChannels;
      _sampleRates = $v.sampleRates;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlatformAudio other) {
    _$v = other as _$PlatformAudio;
  }

  @override
  void update(void Function(PlatformAudioBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlatformAudio build() => _build();

  _$PlatformAudio _build() {
    final _$result =
        _$v ??
        _$PlatformAudio._(
          enabled: BuiltValueNullFieldError.checkNotNull(
            enabled,
            r'PlatformAudio',
            'enabled',
          ),
          output: BuiltValueNullFieldError.checkNotNull(
            output,
            r'PlatformAudio',
            'output',
          ),
          volumeControl: BuiltValueNullFieldError.checkNotNull(
            volumeControl,
            r'PlatformAudio',
            'volumeControl',
          ),
          muteControl: BuiltValueNullFieldError.checkNotNull(
            muteControl,
            r'PlatformAudio',
            'muteControl',
          ),
          audioFocus: BuiltValueNullFieldError.checkNotNull(
            audioFocus,
            r'PlatformAudio',
            'audioFocus',
          ),
          bluetooth: BuiltValueNullFieldError.checkNotNull(
            bluetooth,
            r'PlatformAudio',
            'bluetooth',
          ),
          speaker: BuiltValueNullFieldError.checkNotNull(
            speaker,
            r'PlatformAudio',
            'speaker',
          ),
          headphones: BuiltValueNullFieldError.checkNotNull(
            headphones,
            r'PlatformAudio',
            'headphones',
          ),
          maxChannels: BuiltValueNullFieldError.checkNotNull(
            maxChannels,
            r'PlatformAudio',
            'maxChannels',
          ),
          sampleRates: BuiltValueNullFieldError.checkNotNull(
            sampleRates,
            r'PlatformAudio',
            'sampleRates',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
