// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_adapter_error.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerAdapterError extends PlayerAdapterError {
  @override
  final PlayerAdapterErrorType type;
  @override
  final String message;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;
  @override
  final bool recoverable;
  @override
  final String? backend;
  @override
  final Map<String, Object?> metadata;

  factory _$PlayerAdapterError([
    void Function(PlayerAdapterErrorBuilder)? updates,
  ]) => (PlayerAdapterErrorBuilder()..update(updates))._build();

  _$PlayerAdapterError._({
    required this.type,
    required this.message,
    this.cause,
    this.stackTrace,
    required this.recoverable,
    this.backend,
    required this.metadata,
  }) : super._();
  @override
  PlayerAdapterError rebuild(
    void Function(PlayerAdapterErrorBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PlayerAdapterErrorBuilder toBuilder() =>
      PlayerAdapterErrorBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerAdapterError &&
        type == other.type &&
        message == other.message &&
        cause == other.cause &&
        stackTrace == other.stackTrace &&
        recoverable == other.recoverable &&
        backend == other.backend &&
        metadata == other.metadata;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, cause.hashCode);
    _$hash = $jc(_$hash, stackTrace.hashCode);
    _$hash = $jc(_$hash, recoverable.hashCode);
    _$hash = $jc(_$hash, backend.hashCode);
    _$hash = $jc(_$hash, metadata.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerAdapterError')
          ..add('type', type)
          ..add('message', message)
          ..add('cause', cause)
          ..add('stackTrace', stackTrace)
          ..add('recoverable', recoverable)
          ..add('backend', backend)
          ..add('metadata', metadata))
        .toString();
  }
}

class PlayerAdapterErrorBuilder
    implements Builder<PlayerAdapterError, PlayerAdapterErrorBuilder> {
  _$PlayerAdapterError? _$v;

  PlayerAdapterErrorType? _type;
  PlayerAdapterErrorType? get type => _$this._type;
  set type(PlayerAdapterErrorType? type) => _$this._type = type;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  Object? _cause;
  Object? get cause => _$this._cause;
  set cause(Object? cause) => _$this._cause = cause;

  StackTrace? _stackTrace;
  StackTrace? get stackTrace => _$this._stackTrace;
  set stackTrace(StackTrace? stackTrace) => _$this._stackTrace = stackTrace;

  bool? _recoverable;
  bool? get recoverable => _$this._recoverable;
  set recoverable(bool? recoverable) => _$this._recoverable = recoverable;

  String? _backend;
  String? get backend => _$this._backend;
  set backend(String? backend) => _$this._backend = backend;

  Map<String, Object?>? _metadata;
  Map<String, Object?>? get metadata => _$this._metadata;
  set metadata(Map<String, Object?>? metadata) => _$this._metadata = metadata;

  PlayerAdapterErrorBuilder() {
    PlayerAdapterError._initialize(this);
  }

  PlayerAdapterErrorBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _message = $v.message;
      _cause = $v.cause;
      _stackTrace = $v.stackTrace;
      _recoverable = $v.recoverable;
      _backend = $v.backend;
      _metadata = $v.metadata;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerAdapterError other) {
    _$v = other as _$PlayerAdapterError;
  }

  @override
  void update(void Function(PlayerAdapterErrorBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerAdapterError build() => _build();

  _$PlayerAdapterError _build() {
    final _$result =
        _$v ??
        _$PlayerAdapterError._(
          type: BuiltValueNullFieldError.checkNotNull(
            type,
            r'PlayerAdapterError',
            'type',
          ),
          message: BuiltValueNullFieldError.checkNotNull(
            message,
            r'PlayerAdapterError',
            'message',
          ),
          cause: cause,
          stackTrace: stackTrace,
          recoverable: BuiltValueNullFieldError.checkNotNull(
            recoverable,
            r'PlayerAdapterError',
            'recoverable',
          ),
          backend: backend,
          metadata: BuiltValueNullFieldError.checkNotNull(
            metadata,
            r'PlayerAdapterError',
            'metadata',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
