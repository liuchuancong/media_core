// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_headers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SourceHeaders {

/// Header key-value pairs.
 Map<String, String> get values;/// Whether headers should override defaults.
 bool get overrideDefaults;
/// Create a copy of SourceHeaders
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceHeadersCopyWith<SourceHeaders> get copyWith => _$SourceHeadersCopyWithImpl<SourceHeaders>(this as SourceHeaders, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SourceHeaders;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceHeaders&&const DeepCollectionEquality().equals(other.values, _this.values)&&(identical(other.overrideDefaults, _this.overrideDefaults) || other.overrideDefaults == _this.overrideDefaults));
}


@override
int get hashCode {
  final _this = this as SourceHeaders;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.values),_this.overrideDefaults);
}

@override
String toString() {
  final _this = this as SourceHeaders;
  return 'SourceHeaders(values: ${_this.values}, overrideDefaults: ${_this.overrideDefaults})';
}


}

/// @nodoc
abstract mixin class $SourceHeadersCopyWith<$Res>  {
  factory $SourceHeadersCopyWith(SourceHeaders value, $Res Function(SourceHeaders) _then) = _$SourceHeadersCopyWithImpl;
@useResult
$Res call({
 Map<String, String> values, bool overrideDefaults
});




}
/// @nodoc
class _$SourceHeadersCopyWithImpl<$Res>
    implements $SourceHeadersCopyWith<$Res> {
  _$SourceHeadersCopyWithImpl(this._self, this._then);

  final SourceHeaders _self;
  final $Res Function(SourceHeaders) _then;

/// Create a copy of SourceHeaders
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? values = null,Object? overrideDefaults = null,}) {
  return _then(SourceHeaders(
values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as Map<String, String>,overrideDefaults: null == overrideDefaults ? _self.overrideDefaults : overrideDefaults // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceHeaders].
extension SourceHeadersPatterns on SourceHeaders {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceHeaders value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceHeaders() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceHeaders value)  $default,){
final _that = this;
switch (_that) {
case _SourceHeaders():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceHeaders value)?  $default,){
final _that = this;
switch (_that) {
case _SourceHeaders() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, String> values,  bool overrideDefaults)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceHeaders() when $default != null:
return $default(_that.values,_that.overrideDefaults);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, String> values,  bool overrideDefaults)  $default,) {final _that = this;
switch (_that) {
case _SourceHeaders():
return $default(_that.values,_that.overrideDefaults);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, String> values,  bool overrideDefaults)?  $default,) {final _that = this;
switch (_that) {
case _SourceHeaders() when $default != null:
return $default(_that.values,_that.overrideDefaults);case _:
  return null;

}
}

}

/// @nodoc


class _SourceHeaders implements SourceHeaders {
  const _SourceHeaders({ Map<String, String> values = const {}, this.overrideDefaults = false}): _values = values;
  

/// Header key-value pairs.
 final  Map<String, String> _values;
/// Header key-value pairs.
@override@JsonKey() Map<String, String> get values {
  if (_values is EqualUnmodifiableMapView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_values);
}

/// Whether headers should override defaults.
@override@JsonKey() final  bool overrideDefaults;

/// Create a copy of SourceHeaders
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceHeadersCopyWith<_SourceHeaders> get copyWith => __$SourceHeadersCopyWithImpl<_SourceHeaders>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceHeaders&&const DeepCollectionEquality().equals(other.values, _values)&&(identical(other.overrideDefaults, overrideDefaults) || other.overrideDefaults == overrideDefaults));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_values),overrideDefaults);
}

@override
String toString() {
    return 'SourceHeaders(values: $values, overrideDefaults: $overrideDefaults)';
}


}

/// @nodoc
abstract mixin class _$SourceHeadersCopyWith<$Res> implements $SourceHeadersCopyWith<$Res> {
  factory _$SourceHeadersCopyWith(_SourceHeaders value, $Res Function(_SourceHeaders) _then) = __$SourceHeadersCopyWithImpl;
@override @useResult
$Res call({
 Map<String, String> values, bool overrideDefaults
});




}
/// @nodoc
class __$SourceHeadersCopyWithImpl<$Res>
    implements _$SourceHeadersCopyWith<$Res> {
  __$SourceHeadersCopyWithImpl(this._self, this._then);

  final _SourceHeaders _self;
  final $Res Function(_SourceHeaders) _then;

/// Create a copy of SourceHeaders
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? values = null,Object? overrideDefaults = null,}) {
  return _then(_SourceHeaders(
values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as Map<String, String>,overrideDefaults: null == overrideDefaults ? _self.overrideDefaults : overrideDefaults // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
