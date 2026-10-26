// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_session_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AudioSessionState extends AudioSessionState {
  @override
  final AudioSessionStatus status;
  @override
  final int generation;

  factory _$AudioSessionState([
    void Function(AudioSessionStateBuilder)? updates,
  ]) => (AudioSessionStateBuilder()..update(updates))._build();

  _$AudioSessionState._({required this.status, required this.generation})
    : super._();
  @override
  AudioSessionState rebuild(void Function(AudioSessionStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AudioSessionStateBuilder toBuilder() =>
      AudioSessionStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AudioSessionState &&
        status == other.status &&
        generation == other.generation;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AudioSessionState')
          ..add('status', status)
          ..add('generation', generation))
        .toString();
  }
}

class AudioSessionStateBuilder
    implements Builder<AudioSessionState, AudioSessionStateBuilder> {
  _$AudioSessionState? _$v;

  AudioSessionStatus? _status;
  AudioSessionStatus? get status => _$this._status;
  set status(AudioSessionStatus? status) => _$this._status = status;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  AudioSessionStateBuilder() {
    AudioSessionState._initialize(this);
  }

  AudioSessionStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _status = $v.status;
      _generation = $v.generation;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AudioSessionState other) {
    _$v = other as _$AudioSessionState;
  }

  @override
  void update(void Function(AudioSessionStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AudioSessionState build() => _build();

  _$AudioSessionState _build() {
    final _$result =
        _$v ??
        _$AudioSessionState._(
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'AudioSessionState',
            'status',
          ),
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'AudioSessionState',
            'generation',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
