// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_error.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RecordingError extends RecordingError {
  @override
  final RecordingErrorCode code;
  @override
  final String message;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  factory _$RecordingError([void Function(RecordingErrorBuilder)? updates]) =>
      (RecordingErrorBuilder()..update(updates))._build();

  _$RecordingError._({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  }) : super._();
  @override
  RecordingError rebuild(void Function(RecordingErrorBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RecordingErrorBuilder toBuilder() => RecordingErrorBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RecordingError &&
        code == other.code &&
        message == other.message &&
        cause == other.cause &&
        stackTrace == other.stackTrace;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, code.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, cause.hashCode);
    _$hash = $jc(_$hash, stackTrace.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RecordingError')
          ..add('code', code)
          ..add('message', message)
          ..add('cause', cause)
          ..add('stackTrace', stackTrace))
        .toString();
  }
}

class RecordingErrorBuilder
    implements Builder<RecordingError, RecordingErrorBuilder> {
  _$RecordingError? _$v;

  RecordingErrorCode? _code;
  RecordingErrorCode? get code => _$this._code;
  set code(RecordingErrorCode? code) => _$this._code = code;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  Object? _cause;
  Object? get cause => _$this._cause;
  set cause(Object? cause) => _$this._cause = cause;

  StackTrace? _stackTrace;
  StackTrace? get stackTrace => _$this._stackTrace;
  set stackTrace(StackTrace? stackTrace) => _$this._stackTrace = stackTrace;

  RecordingErrorBuilder();

  RecordingErrorBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _code = $v.code;
      _message = $v.message;
      _cause = $v.cause;
      _stackTrace = $v.stackTrace;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RecordingError other) {
    _$v = other as _$RecordingError;
  }

  @override
  void update(void Function(RecordingErrorBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RecordingError build() => _build();

  _$RecordingError _build() {
    final _$result =
        _$v ??
        _$RecordingError._(
          code: BuiltValueNullFieldError.checkNotNull(
            code,
            r'RecordingError',
            'code',
          ),
          message: BuiltValueNullFieldError.checkNotNull(
            message,
            r'RecordingError',
            'message',
          ),
          cause: cause,
          stackTrace: stackTrace,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
