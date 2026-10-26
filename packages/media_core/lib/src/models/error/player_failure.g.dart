// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_failure.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlayerFailure extends PlayerFailure {
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

  factory _$PlayerFailure([void Function(PlayerFailureBuilder)? updates]) =>
      (PlayerFailureBuilder()..update(updates))._build();

  _$PlayerFailure._({
    required this.code,
    this.message,
    this.cause,
    this.stackTrace,
    this.context,
    this.category,
  }) : super._();
  @override
  PlayerFailure rebuild(void Function(PlayerFailureBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlayerFailureBuilder toBuilder() => PlayerFailureBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlayerFailure &&
        code == other.code &&
        message == other.message &&
        cause == other.cause &&
        stackTrace == other.stackTrace &&
        context == other.context &&
        category == other.category;
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
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlayerFailure')
          ..add('code', code)
          ..add('message', message)
          ..add('cause', cause)
          ..add('stackTrace', stackTrace)
          ..add('context', context)
          ..add('category', category))
        .toString();
  }
}

class PlayerFailureBuilder
    implements Builder<PlayerFailure, PlayerFailureBuilder> {
  _$PlayerFailure? _$v;

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

  ErrorContextBuilder? _context;
  ErrorContextBuilder get context => _$this._context ??= ErrorContextBuilder();
  set context(ErrorContextBuilder? context) => _$this._context = context;

  PlayerErrorCategory? _category;
  PlayerErrorCategory? get category => _$this._category;
  set category(PlayerErrorCategory? category) => _$this._category = category;

  PlayerFailureBuilder();

  PlayerFailureBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _code = $v.code;
      _message = $v.message;
      _cause = $v.cause;
      _stackTrace = $v.stackTrace;
      _context = $v.context?.toBuilder();
      _category = $v.category;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlayerFailure other) {
    _$v = other as _$PlayerFailure;
  }

  @override
  void update(void Function(PlayerFailureBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlayerFailure build() => _build();

  _$PlayerFailure _build() {
    _$PlayerFailure _$result;
    try {
      _$result =
          _$v ??
          _$PlayerFailure._(
            code: BuiltValueNullFieldError.checkNotNull(
              code,
              r'PlayerFailure',
              'code',
            ),
            message: message,
            cause: cause,
            stackTrace: stackTrace,
            context: _context?.build(),
            category: category,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'context';
        _context?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PlayerFailure',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
