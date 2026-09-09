// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'presentation_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PresentationSnapshot {

/// Current active presentation mode.
///
/// This is the last successfully completed mode.
 PresentationMode get mode;/// Target presentation mode.
///
/// Exists while transition is running.
///
/// Example:
///
/// mode:
/// normal
///
/// targetMode:
/// fullscreen
///
/// transitioning:
/// true
 PresentationMode? get targetMode;/// Current capabilities.
 PresentationCapabilities get capabilities;/// Whether transition is running.
 bool get transitioning;/// Whether presentation is enabled.
 bool get enabled;/// Lifecycle generation.
///
/// Used to ignore stale async callbacks.
 int get generation;/// Last error.
 String? get error;
/// Create a copy of PresentationSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PresentationSnapshotCopyWith<PresentationSnapshot> get copyWith => _$PresentationSnapshotCopyWithImpl<PresentationSnapshot>(this as PresentationSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PresentationSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PresentationSnapshot&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.targetMode, _this.targetMode) || other.targetMode == _this.targetMode)&&(identical(other.capabilities, _this.capabilities) || other.capabilities == _this.capabilities)&&(identical(other.transitioning, _this.transitioning) || other.transitioning == _this.transitioning)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as PresentationSnapshot;
  return Object.hash(runtimeType,_this.mode,_this.targetMode,_this.capabilities,_this.transitioning,_this.enabled,_this.generation,_this.error);
}

@override
String toString() {
  final _this = this as PresentationSnapshot;
  return 'PresentationSnapshot(mode: ${_this.mode}, targetMode: ${_this.targetMode}, capabilities: ${_this.capabilities}, transitioning: ${_this.transitioning}, enabled: ${_this.enabled}, generation: ${_this.generation}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $PresentationSnapshotCopyWith<$Res>  {
  factory $PresentationSnapshotCopyWith(PresentationSnapshot value, $Res Function(PresentationSnapshot) _then) = _$PresentationSnapshotCopyWithImpl;
@useResult
$Res call({
 PresentationMode mode, PresentationMode? targetMode, PresentationCapabilities capabilities, bool transitioning, bool enabled, int generation, String? error
});


$PresentationCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class _$PresentationSnapshotCopyWithImpl<$Res>
    implements $PresentationSnapshotCopyWith<$Res> {
  _$PresentationSnapshotCopyWithImpl(this._self, this._then);

  final PresentationSnapshot _self;
  final $Res Function(PresentationSnapshot) _then;

/// Create a copy of PresentationSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? targetMode = freezed,Object? capabilities = null,Object? transitioning = null,Object? enabled = null,Object? generation = null,Object? error = freezed,}) {
  return _then(PresentationSnapshot(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PresentationMode,targetMode: freezed == targetMode ? _self.targetMode : targetMode // ignore: cast_nullable_to_non_nullable
as PresentationMode?,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as PresentationCapabilities,transitioning: null == transitioning ? _self.transitioning : transitioning // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of PresentationSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PresentationCapabilitiesCopyWith<$Res> get capabilities {
  
  return $PresentationCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}


/// Adds pattern-matching-related methods to [PresentationSnapshot].
extension PresentationSnapshotPatterns on PresentationSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PresentationSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PresentationSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PresentationSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _PresentationSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PresentationSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _PresentationSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PresentationMode mode,  PresentationMode? targetMode,  PresentationCapabilities capabilities,  bool transitioning,  bool enabled,  int generation,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PresentationSnapshot() when $default != null:
return $default(_that.mode,_that.targetMode,_that.capabilities,_that.transitioning,_that.enabled,_that.generation,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PresentationMode mode,  PresentationMode? targetMode,  PresentationCapabilities capabilities,  bool transitioning,  bool enabled,  int generation,  String? error)  $default,) {final _that = this;
switch (_that) {
case _PresentationSnapshot():
return $default(_that.mode,_that.targetMode,_that.capabilities,_that.transitioning,_that.enabled,_that.generation,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PresentationMode mode,  PresentationMode? targetMode,  PresentationCapabilities capabilities,  bool transitioning,  bool enabled,  int generation,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _PresentationSnapshot() when $default != null:
return $default(_that.mode,_that.targetMode,_that.capabilities,_that.transitioning,_that.enabled,_that.generation,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _PresentationSnapshot extends PresentationSnapshot {
  const _PresentationSnapshot({this.mode = PresentationMode.normal, this.targetMode, this.capabilities = const PresentationCapabilities(), this.transitioning = false, this.enabled = true, this.generation = 0, this.error}): super._();
  

/// Current active presentation mode.
///
/// This is the last successfully completed mode.
@override@JsonKey() final  PresentationMode mode;
/// Target presentation mode.
///
/// Exists while transition is running.
///
/// Example:
///
/// mode:
/// normal
///
/// targetMode:
/// fullscreen
///
/// transitioning:
/// true
@override final  PresentationMode? targetMode;
/// Current capabilities.
@override@JsonKey() final  PresentationCapabilities capabilities;
/// Whether transition is running.
@override@JsonKey() final  bool transitioning;
/// Whether presentation is enabled.
@override@JsonKey() final  bool enabled;
/// Lifecycle generation.
///
/// Used to ignore stale async callbacks.
@override@JsonKey() final  int generation;
/// Last error.
@override final  String? error;

/// Create a copy of PresentationSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PresentationSnapshotCopyWith<_PresentationSnapshot> get copyWith => __$PresentationSnapshotCopyWithImpl<_PresentationSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PresentationSnapshot&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.targetMode, targetMode) || other.targetMode == targetMode)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities)&&(identical(other.transitioning, transitioning) || other.transitioning == transitioning)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mode,targetMode,capabilities,transitioning,enabled,generation,error);
}

@override
String toString() {
    return 'PresentationSnapshot(mode: $mode, targetMode: $targetMode, capabilities: $capabilities, transitioning: $transitioning, enabled: $enabled, generation: $generation, error: $error)';
}


}

/// @nodoc
abstract mixin class _$PresentationSnapshotCopyWith<$Res> implements $PresentationSnapshotCopyWith<$Res> {
  factory _$PresentationSnapshotCopyWith(_PresentationSnapshot value, $Res Function(_PresentationSnapshot) _then) = __$PresentationSnapshotCopyWithImpl;
@override @useResult
$Res call({
 PresentationMode mode, PresentationMode? targetMode, PresentationCapabilities capabilities, bool transitioning, bool enabled, int generation, String? error
});


@override $PresentationCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class __$PresentationSnapshotCopyWithImpl<$Res>
    implements _$PresentationSnapshotCopyWith<$Res> {
  __$PresentationSnapshotCopyWithImpl(this._self, this._then);

  final _PresentationSnapshot _self;
  final $Res Function(_PresentationSnapshot) _then;

/// Create a copy of PresentationSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? targetMode = freezed,Object? capabilities = null,Object? transitioning = null,Object? enabled = null,Object? generation = null,Object? error = freezed,}) {
  return _then(_PresentationSnapshot(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PresentationMode,targetMode: freezed == targetMode ? _self.targetMode : targetMode // ignore: cast_nullable_to_non_nullable
as PresentationMode?,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as PresentationCapabilities,transitioning: null == transitioning ? _self.transitioning : transitioning // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of PresentationSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PresentationCapabilitiesCopyWith<$Res> get capabilities {
  
  return $PresentationCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}

// dart format on
