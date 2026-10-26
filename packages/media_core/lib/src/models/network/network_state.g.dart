// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NetworkState extends NetworkState {
  @override
  final bool connected;
  @override
  final NetworkType type;
  @override
  final NetworkQuality quality;
  @override
  final bool metered;
  @override
  final bool expensive;
  @override
  final DateTime? updatedAt;

  factory _$NetworkState([void Function(NetworkStateBuilder)? updates]) =>
      (NetworkStateBuilder()..update(updates))._build();

  _$NetworkState._({
    required this.connected,
    required this.type,
    required this.quality,
    required this.metered,
    required this.expensive,
    this.updatedAt,
  }) : super._();
  @override
  NetworkState rebuild(void Function(NetworkStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NetworkStateBuilder toBuilder() => NetworkStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NetworkState &&
        connected == other.connected &&
        type == other.type &&
        quality == other.quality &&
        metered == other.metered &&
        expensive == other.expensive &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, connected.hashCode);
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, quality.hashCode);
    _$hash = $jc(_$hash, metered.hashCode);
    _$hash = $jc(_$hash, expensive.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NetworkState')
          ..add('connected', connected)
          ..add('type', type)
          ..add('quality', quality)
          ..add('metered', metered)
          ..add('expensive', expensive)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class NetworkStateBuilder
    implements Builder<NetworkState, NetworkStateBuilder> {
  _$NetworkState? _$v;

  bool? _connected;
  bool? get connected => _$this._connected;
  set connected(bool? connected) => _$this._connected = connected;

  NetworkType? _type;
  NetworkType? get type => _$this._type;
  set type(NetworkType? type) => _$this._type = type;

  NetworkQuality? _quality;
  NetworkQuality? get quality => _$this._quality;
  set quality(NetworkQuality? quality) => _$this._quality = quality;

  bool? _metered;
  bool? get metered => _$this._metered;
  set metered(bool? metered) => _$this._metered = metered;

  bool? _expensive;
  bool? get expensive => _$this._expensive;
  set expensive(bool? expensive) => _$this._expensive = expensive;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  NetworkStateBuilder() {
    NetworkState._initialize(this);
  }

  NetworkStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _connected = $v.connected;
      _type = $v.type;
      _quality = $v.quality;
      _metered = $v.metered;
      _expensive = $v.expensive;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NetworkState other) {
    _$v = other as _$NetworkState;
  }

  @override
  void update(void Function(NetworkStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NetworkState build() => _build();

  _$NetworkState _build() {
    final _$result =
        _$v ??
        _$NetworkState._(
          connected: BuiltValueNullFieldError.checkNotNull(
            connected,
            r'NetworkState',
            'connected',
          ),
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'NetworkState',
            'type',
          ),
          quality: BuiltValueNullFieldError.checkNotNull(
            quality,
            r'NetworkState',
            'quality',
          ),
          metered: BuiltValueNullFieldError.checkNotNull(
            metered,
            r'NetworkState',
            'metered',
          ),
          expensive: BuiltValueNullFieldError.checkNotNull(
            expensive,
            r'NetworkState',
            'expensive',
          ),
          updatedAt: updatedAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
