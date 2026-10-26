// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'result_error.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResultError extends ResultError {
  @override
  final PlayerErrorCode code;
  @override
  final String? message;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;
  @override
  final ErrorContext? context;
  @override
  final PlayerErrorCategory? category;
  @override
  final PlayerFailure? failure;

  factory _$ResultError([void Function(ResultErrorBuilder)? updates]) =>
      (ResultErrorBuilder()..update(updates))._build();

  _$ResultError._({
    required this.code,
    this.message,
    this.cause,
    this.stackTrace,
    this.context,
    this.category,
    this.failure,
  }) : super._();
  @override
  ResultError rebuild(void Function(ResultErrorBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ResultErrorBuilder toBuilder() => ResultErrorBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResultError &&
        code == other.code &&
        message == other.message &&
        cause == other.cause &&
        stackTrace == other.stackTrace &&
        context == other.context &&
        category == other.category &&
        failure == other.failure;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, code.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, cause.hashCode);
    _$hash = $jc(_$hash, stackTrace.hashCode);
    _$hash = $jc(_$hash, context.hashCode);
    _$hash = $jc(_$hash, category.hashCode);
    _$hash = $jc(_$hash, failure.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ResultError')
          ..add('code', code)
          ..add('message', message)
          ..add('cause', cause)
          ..add('stackTrace', stackTrace)
          ..add('context', context)
          ..add('category', category)
          ..add('failure', failure))
        .toString();
  }
}

class ResultErrorBuilder implements Builder<ResultError, ResultErrorBuilder> {
  _$ResultError? _$v;

  PlayerErrorCode? _code;
  PlayerErrorCode? get code => _$this._code;
  set code(PlayerErrorCode? code) => _$this._code = code;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  Object? _cause;
  Object? get cause => _$this._cause;
  set cause(Object? cause) => _$this._cause = cause;

  StackTrace? _stackTrace;
  StackTrace? get stackTrace => _$this._stackTrace;
  set stackTrace(StackTrace? stackTrace) => _$this._stackTrace = stackTrace;

  ErrorContext? _context;
  ErrorContext? get context => _$this._context;
  set context(ErrorContext? context) => _$this._context = context;

  PlayerErrorCategory? _category;
  PlayerErrorCategory? get category => _$this._category;
  set category(PlayerErrorCategory? category) => _$this._category = category;

  PlayerFailure? _failure;
  PlayerFailure? get failure => _$this._failure;
  set failure(PlayerFailure? failure) => _$this._failure = failure;

  ResultErrorBuilder();

  ResultErrorBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _code = $v.code;
      _message = $v.message;
      _cause = $v.cause;
      _stackTrace = $v.stackTrace;
      _context = $v.context;
      _category = $v.category;
      _failure = $v.failure;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResultError other) {
    _$v = other as _$ResultError;
  }

  @override
  void update(void Function(ResultErrorBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResultError build() => _build();

  _$ResultError _build() {
    final _$result =
        _$v ??
        _$ResultError._(
          code: BuiltValueNullFieldError.checkNotNull(
            code,
            r'ResultError',
            'code',
          ),
          message: message,
          cause: cause,
          stackTrace: stackTrace,
          context: context,
          category: category,
          failure: failure,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
