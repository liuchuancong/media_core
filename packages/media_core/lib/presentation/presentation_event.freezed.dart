// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'presentation_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PresentationEvent {

/// Event type.
 PresentationEventType get type;/// Related presentation mode.
 PresentationMode? get mode;/// Lifecycle generation.
///
/// Used to discard stale asynchronous callbacks.
 int get generation;/// Optional event source.
 String? get source;/// Optional error message.
 String? get error;
/// Create a copy of PresentationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PresentationEventCopyWith<PresentationEvent> get copyWith => _$PresentationEventCopyWithImpl<PresentationEvent>(this as PresentationEvent, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PresentationEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PresentationEvent&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as PresentationEvent;
  return Object.hash(runtimeType,_this.type,_this.mode,_this.generation,_this.source,_this.error);
}

@override
String toString() {
  final _this = this as PresentationEvent;
  return 'PresentationEvent(type: ${_this.type}, mode: ${_this.mode}, generation: ${_this.generation}, source: ${_this.source}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $PresentationEventCopyWith<$Res>  {
  factory $PresentationEventCopyWith(PresentationEvent value, $Res Function(PresentationEvent) _then) = _$PresentationEventCopyWithImpl;
@useResult
$Res call({
 PresentationEventType type, PresentationMode? mode, int generation, String? source, String? error
});




}
/// @nodoc
class _$PresentationEventCopyWithImpl<$Res>
    implements $PresentationEventCopyWith<$Res> {
  _$PresentationEventCopyWithImpl(this._self, this._then);

  final PresentationEvent _self;
  final $Res Function(PresentationEvent) _then;

/// Create a copy of PresentationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? mode = freezed,Object? generation = null,Object? source = freezed,Object? error = freezed,}) {
  return _then(PresentationEvent(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as PresentationEventType,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PresentationMode?,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PresentationEvent].
extension PresentationEventPatterns on PresentationEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PresentationEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PresentationEvent() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PresentationEvent value)  $default,){
final _that = this;
switch (_that) {
case _PresentationEvent():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PresentationEvent value)?  $default,){
final _that = this;
switch (_that) {
case _PresentationEvent() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PresentationEventType type,  PresentationMode? mode,  int generation,  String? source,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PresentationEvent() when $default != null:
return $default(_that.type,_that.mode,_that.generation,_that.source,_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PresentationEventType type,  PresentationMode? mode,  int generation,  String? source,  String? error)  $default,) {final _that = this;
switch (_that) {
case _PresentationEvent():
return $default(_that.type,_that.mode,_that.generation,_that.source,_that.error);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PresentationEventType type,  PresentationMode? mode,  int generation,  String? source,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _PresentationEvent() when $default != null:
return $default(_that.type,_that.mode,_that.generation,_that.source,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _PresentationEvent extends PresentationEvent {
  const _PresentationEvent({required this.type, this.mode, this.generation = 0, this.source, this.error}): super._();
  

/// Event type.
@override final  PresentationEventType type;
/// Related presentation mode.
@override final  PresentationMode? mode;
/// Lifecycle generation.
///
/// Used to discard stale asynchronous callbacks.
@override@JsonKey() final  int generation;
/// Optional event source.
@override final  String? source;
/// Optional error message.
@override final  String? error;

/// Create a copy of PresentationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PresentationEventCopyWith<_PresentationEvent> get copyWith => __$PresentationEventCopyWithImpl<_PresentationEvent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PresentationEvent&&(identical(other.type, type) || other.type == type)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.source, source) || other.source == source)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,type,mode,generation,source,error);
}

@override
String toString() {
    return 'PresentationEvent(type: $type, mode: $mode, generation: $generation, source: $source, error: $error)';
}


}

/// @nodoc
abstract mixin class _$PresentationEventCopyWith<$Res> implements $PresentationEventCopyWith<$Res> {
  factory _$PresentationEventCopyWith(_PresentationEvent value, $Res Function(_PresentationEvent) _then) = __$PresentationEventCopyWithImpl;
@override @useResult
$Res call({
 PresentationEventType type, PresentationMode? mode, int generation, String? source, String? error
});




}
/// @nodoc
class __$PresentationEventCopyWithImpl<$Res>
    implements _$PresentationEventCopyWith<$Res> {
  __$PresentationEventCopyWithImpl(this._self, this._then);

  final _PresentationEvent _self;
  final $Res Function(_PresentationEvent) _then;

/// Create a copy of PresentationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? mode = freezed,Object? generation = null,Object? source = freezed,Object? error = freezed,}) {
  return _then(_PresentationEvent(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as PresentationEventType,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PresentationMode?,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
