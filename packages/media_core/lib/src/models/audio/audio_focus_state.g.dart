// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_focus_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AudioFocusState extends AudioFocusState {
  @override
  final AudioFocusStatus status;
  @override
  final int generation;

  factory _$AudioFocusState([void Function(AudioFocusStateBuilder)? updates]) =>
      (AudioFocusStateBuilder()..update(updates))._build();

  _$AudioFocusState._({required this.status, required this.generation})
    : super._();
  @override
  AudioFocusState rebuild(void Function(AudioFocusStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AudioFocusStateBuilder toBuilder() => AudioFocusStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AudioFocusState &&
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
    return (newBuiltValueToStringHelper(r'AudioFocusState')
          ..add('status', status)
          ..add('generation', generation))
        .toString();
  }
}

class AudioFocusStateBuilder
    implements Builder<AudioFocusState, AudioFocusStateBuilder> {
  _$AudioFocusState? _$v;

  AudioFocusStatus? _status;
  AudioFocusStatus? get status => _$this._status;
  set status(AudioFocusStatus? status) => _$this._status = status;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  AudioFocusStateBuilder() {
    AudioFocusState._initialize(this);
  }

  AudioFocusStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _status = $v.status;
      _generation = $v.generation;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AudioFocusState other) {
    _$v = other as _$AudioFocusState;
  }

  @override
  void update(void Function(AudioFocusStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AudioFocusState build() => _build();

  _$AudioFocusState _build() {
    final _$result =
        _$v ??
        _$AudioFocusState._(
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'AudioFocusState',
            'status',
          ),
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'AudioFocusState',
            'generation',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
