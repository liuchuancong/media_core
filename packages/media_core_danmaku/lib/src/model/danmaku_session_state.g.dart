// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'danmaku_session_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DanmakuSessionState extends DanmakuSessionState {
  @override
  final DanmakuSessionPhase phase;
  @override
  final String? roomKey;
  @override
  final String? roomId;
  @override
  final String? platform;
  @override
  final String? transportId;
  @override
  final int generation;
  @override
  final DanmakuFailure? failure;
  @override
  final bool installed;

  factory _$DanmakuSessionState([
    void Function(DanmakuSessionStateBuilder)? updates,
  ]) => (DanmakuSessionStateBuilder()..update(updates))._build();

  _$DanmakuSessionState._({
    required this.phase,
    this.roomKey,
    this.roomId,
    this.platform,
    this.transportId,
    required this.generation,
    this.failure,
    required this.installed,
  }) : super._();
  @override
  DanmakuSessionState rebuild(
    void Function(DanmakuSessionStateBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DanmakuSessionStateBuilder toBuilder() =>
      DanmakuSessionStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DanmakuSessionState &&
        phase == other.phase &&
        roomKey == other.roomKey &&
        roomId == other.roomId &&
        platform == other.platform &&
        transportId == other.transportId &&
        generation == other.generation &&
        failure == other.failure &&
        installed == other.installed;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, phase.hashCode);
    _$hash = $jc(_$hash, roomKey.hashCode);
    _$hash = $jc(_$hash, roomId.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, transportId.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, failure.hashCode);
    _$hash = $jc(_$hash, installed.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DanmakuSessionState')
          ..add('phase', phase)
          ..add('roomKey', roomKey)
          ..add('roomId', roomId)
          ..add('platform', platform)
          ..add('transportId', transportId)
          ..add('generation', generation)
          ..add('failure', failure)
          ..add('installed', installed))
        .toString();
  }
}

class DanmakuSessionStateBuilder
    implements Builder<DanmakuSessionState, DanmakuSessionStateBuilder> {
  _$DanmakuSessionState? _$v;

  DanmakuSessionPhase? _phase;
  DanmakuSessionPhase? get phase => _$this._phase;
  set phase(DanmakuSessionPhase? phase) => _$this._phase = phase;

  String? _roomKey;
  String? get roomKey => _$this._roomKey;
  set roomKey(String? roomKey) => _$this._roomKey = roomKey;

  String? _roomId;
  String? get roomId => _$this._roomId;
  set roomId(String? roomId) => _$this._roomId = roomId;

  String? _platform;
  String? get platform => _$this._platform;
  set platform(String? platform) => _$this._platform = platform;

  String? _transportId;
  String? get transportId => _$this._transportId;
  set transportId(String? transportId) => _$this._transportId = transportId;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  DanmakuFailure? _failure;
  DanmakuFailure? get failure => _$this._failure;
  set failure(DanmakuFailure? failure) => _$this._failure = failure;

  bool? _installed;
  bool? get installed => _$this._installed;
  set installed(bool? installed) => _$this._installed = installed;

  DanmakuSessionStateBuilder() {
    DanmakuSessionState._initialize(this);
  }

  DanmakuSessionStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _phase = $v.phase;
      _roomKey = $v.roomKey;
      _roomId = $v.roomId;
      _platform = $v.platform;
      _transportId = $v.transportId;
      _generation = $v.generation;
      _failure = $v.failure;
      _installed = $v.installed;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DanmakuSessionState other) {
    _$v = other as _$DanmakuSessionState;
  }

  @override
  void update(void Function(DanmakuSessionStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DanmakuSessionState build() => _build();

  _$DanmakuSessionState _build() {
    final _$result =
        _$v ??
        _$DanmakuSessionState._(
          phase: BuiltValueNullFieldError.checkNotNull(
            phase,
            r'DanmakuSessionState',
            'phase',
          ),
          roomKey: roomKey,
          roomId: roomId,
          platform: platform,
          transportId: transportId,
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'DanmakuSessionState',
            'generation',
          ),
          failure: failure,
          installed: BuiltValueNullFieldError.checkNotNull(
            installed,
            r'DanmakuSessionState',
            'installed',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
