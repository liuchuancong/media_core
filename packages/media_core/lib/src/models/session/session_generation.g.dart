// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_generation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SessionGeneration extends SessionGeneration {
  @override
  final GenerationId id;
  @override
  final int number;

  factory _$SessionGeneration([
    void Function(SessionGenerationBuilder)? updates,
  ]) => (SessionGenerationBuilder()..update(updates))._build();

  _$SessionGeneration._({required this.id, required this.number}) : super._();
  @override
  SessionGeneration rebuild(void Function(SessionGenerationBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SessionGenerationBuilder toBuilder() =>
      SessionGenerationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SessionGeneration &&
        id == other.id &&
        number == other.number;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, number.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SessionGeneration')
          ..add('id', id)
          ..add('number', number))
        .toString();
  }
}

class SessionGenerationBuilder
    implements Builder<SessionGeneration, SessionGenerationBuilder> {
  _$SessionGeneration? _$v;

  GenerationId? _id;
  GenerationId? get id => _$this._id;
  set id(GenerationId? id) => _$this._id = id;

  int? _number;
  int? get number => _$this._number;
  set number(int? number) => _$this._number = number;

  SessionGenerationBuilder();

  SessionGenerationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _number = $v.number;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SessionGeneration other) {
    _$v = other as _$SessionGeneration;
  }

  @override
  void update(void Function(SessionGenerationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SessionGeneration build() => _build();

  _$SessionGeneration _build() {
    final _$result =
        _$v ??
        _$SessionGeneration._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'SessionGeneration',
            'id',
          ),
          number: BuiltValueNullFieldError.checkNotNull(
            number,
            r'SessionGeneration',
            'number',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
