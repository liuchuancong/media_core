// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_adapter_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlayerAdapterEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PlayerAdapterEvent()';
}


}

/// @nodoc
class $PlayerAdapterEventCopyWith<$Res>  {
$PlayerAdapterEventCopyWith(PlayerAdapterEvent _, $Res Function(PlayerAdapterEvent) __);
}


/// Adds pattern-matching-related methods to [PlayerAdapterEvent].
extension PlayerAdapterEventPatterns on PlayerAdapterEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PlayerAdapterOpened value)?  opened,TResult Function( PlayerAdapterPlaying value)?  playing,TResult Function( PlayerAdapterPaused value)?  paused,TResult Function( PlayerAdapterStopped value)?  stopped,TResult Function( PlayerAdapterBuffering value)?  buffering,TResult Function( PlayerAdapterCompleted value)?  completed,TResult Function( PlayerAdapterPositionChanged value)?  positionChanged,TResult Function( PlayerAdapterDurationChanged value)?  durationChanged,TResult Function( PlayerAdapterVideoSizeChanged value)?  videoSizeChanged,TResult Function( PlayerAdapterVolumeChanged value)?  volumeChanged,TResult Function( PlayerAdapterRateChanged value)?  rateChanged,TResult Function( PlayerAdapterErrorEvent value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PlayerAdapterOpened() when opened != null:
return opened(_that);case PlayerAdapterPlaying() when playing != null:
return playing(_that);case PlayerAdapterPaused() when paused != null:
return paused(_that);case PlayerAdapterStopped() when stopped != null:
return stopped(_that);case PlayerAdapterBuffering() when buffering != null:
return buffering(_that);case PlayerAdapterCompleted() when completed != null:
return completed(_that);case PlayerAdapterPositionChanged() when positionChanged != null:
return positionChanged(_that);case PlayerAdapterDurationChanged() when durationChanged != null:
return durationChanged(_that);case PlayerAdapterVideoSizeChanged() when videoSizeChanged != null:
return videoSizeChanged(_that);case PlayerAdapterVolumeChanged() when volumeChanged != null:
return volumeChanged(_that);case PlayerAdapterRateChanged() when rateChanged != null:
return rateChanged(_that);case PlayerAdapterErrorEvent() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PlayerAdapterOpened value)  opened,required TResult Function( PlayerAdapterPlaying value)  playing,required TResult Function( PlayerAdapterPaused value)  paused,required TResult Function( PlayerAdapterStopped value)  stopped,required TResult Function( PlayerAdapterBuffering value)  buffering,required TResult Function( PlayerAdapterCompleted value)  completed,required TResult Function( PlayerAdapterPositionChanged value)  positionChanged,required TResult Function( PlayerAdapterDurationChanged value)  durationChanged,required TResult Function( PlayerAdapterVideoSizeChanged value)  videoSizeChanged,required TResult Function( PlayerAdapterVolumeChanged value)  volumeChanged,required TResult Function( PlayerAdapterRateChanged value)  rateChanged,required TResult Function( PlayerAdapterErrorEvent value)  error,}){
final _that = this;
switch (_that) {
case PlayerAdapterOpened():
return opened(_that);case PlayerAdapterPlaying():
return playing(_that);case PlayerAdapterPaused():
return paused(_that);case PlayerAdapterStopped():
return stopped(_that);case PlayerAdapterBuffering():
return buffering(_that);case PlayerAdapterCompleted():
return completed(_that);case PlayerAdapterPositionChanged():
return positionChanged(_that);case PlayerAdapterDurationChanged():
return durationChanged(_that);case PlayerAdapterVideoSizeChanged():
return videoSizeChanged(_that);case PlayerAdapterVolumeChanged():
return volumeChanged(_that);case PlayerAdapterRateChanged():
return rateChanged(_that);case PlayerAdapterErrorEvent():
return error(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PlayerAdapterOpened value)?  opened,TResult? Function( PlayerAdapterPlaying value)?  playing,TResult? Function( PlayerAdapterPaused value)?  paused,TResult? Function( PlayerAdapterStopped value)?  stopped,TResult? Function( PlayerAdapterBuffering value)?  buffering,TResult? Function( PlayerAdapterCompleted value)?  completed,TResult? Function( PlayerAdapterPositionChanged value)?  positionChanged,TResult? Function( PlayerAdapterDurationChanged value)?  durationChanged,TResult? Function( PlayerAdapterVideoSizeChanged value)?  videoSizeChanged,TResult? Function( PlayerAdapterVolumeChanged value)?  volumeChanged,TResult? Function( PlayerAdapterRateChanged value)?  rateChanged,TResult? Function( PlayerAdapterErrorEvent value)?  error,}){
final _that = this;
switch (_that) {
case PlayerAdapterOpened() when opened != null:
return opened(_that);case PlayerAdapterPlaying() when playing != null:
return playing(_that);case PlayerAdapterPaused() when paused != null:
return paused(_that);case PlayerAdapterStopped() when stopped != null:
return stopped(_that);case PlayerAdapterBuffering() when buffering != null:
return buffering(_that);case PlayerAdapterCompleted() when completed != null:
return completed(_that);case PlayerAdapterPositionChanged() when positionChanged != null:
return positionChanged(_that);case PlayerAdapterDurationChanged() when durationChanged != null:
return durationChanged(_that);case PlayerAdapterVideoSizeChanged() when videoSizeChanged != null:
return videoSizeChanged(_that);case PlayerAdapterVolumeChanged() when volumeChanged != null:
return volumeChanged(_that);case PlayerAdapterRateChanged() when rateChanged != null:
return rateChanged(_that);case PlayerAdapterErrorEvent() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String? source)?  opened,TResult Function()?  playing,TResult Function()?  paused,TResult Function()?  stopped,TResult Function( bool buffering,  double? progress)?  buffering,TResult Function()?  completed,TResult Function( Duration position)?  positionChanged,TResult Function( Duration duration)?  durationChanged,TResult Function( int width,  int height)?  videoSizeChanged,TResult Function( double volume)?  volumeChanged,TResult Function( double rate)?  rateChanged,TResult Function( String message,  Object? error,  StackTrace? stackTrace)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PlayerAdapterOpened() when opened != null:
return opened(_that.source);case PlayerAdapterPlaying() when playing != null:
return playing();case PlayerAdapterPaused() when paused != null:
return paused();case PlayerAdapterStopped() when stopped != null:
return stopped();case PlayerAdapterBuffering() when buffering != null:
return buffering(_that.buffering,_that.progress);case PlayerAdapterCompleted() when completed != null:
return completed();case PlayerAdapterPositionChanged() when positionChanged != null:
return positionChanged(_that.position);case PlayerAdapterDurationChanged() when durationChanged != null:
return durationChanged(_that.duration);case PlayerAdapterVideoSizeChanged() when videoSizeChanged != null:
return videoSizeChanged(_that.width,_that.height);case PlayerAdapterVolumeChanged() when volumeChanged != null:
return volumeChanged(_that.volume);case PlayerAdapterRateChanged() when rateChanged != null:
return rateChanged(_that.rate);case PlayerAdapterErrorEvent() when error != null:
return error(_that.message,_that.error,_that.stackTrace);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String? source)  opened,required TResult Function()  playing,required TResult Function()  paused,required TResult Function()  stopped,required TResult Function( bool buffering,  double? progress)  buffering,required TResult Function()  completed,required TResult Function( Duration position)  positionChanged,required TResult Function( Duration duration)  durationChanged,required TResult Function( int width,  int height)  videoSizeChanged,required TResult Function( double volume)  volumeChanged,required TResult Function( double rate)  rateChanged,required TResult Function( String message,  Object? error,  StackTrace? stackTrace)  error,}) {final _that = this;
switch (_that) {
case PlayerAdapterOpened():
return opened(_that.source);case PlayerAdapterPlaying():
return playing();case PlayerAdapterPaused():
return paused();case PlayerAdapterStopped():
return stopped();case PlayerAdapterBuffering():
return buffering(_that.buffering,_that.progress);case PlayerAdapterCompleted():
return completed();case PlayerAdapterPositionChanged():
return positionChanged(_that.position);case PlayerAdapterDurationChanged():
return durationChanged(_that.duration);case PlayerAdapterVideoSizeChanged():
return videoSizeChanged(_that.width,_that.height);case PlayerAdapterVolumeChanged():
return volumeChanged(_that.volume);case PlayerAdapterRateChanged():
return rateChanged(_that.rate);case PlayerAdapterErrorEvent():
return error(_that.message,_that.error,_that.stackTrace);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String? source)?  opened,TResult? Function()?  playing,TResult? Function()?  paused,TResult? Function()?  stopped,TResult? Function( bool buffering,  double? progress)?  buffering,TResult? Function()?  completed,TResult? Function( Duration position)?  positionChanged,TResult? Function( Duration duration)?  durationChanged,TResult? Function( int width,  int height)?  videoSizeChanged,TResult? Function( double volume)?  volumeChanged,TResult? Function( double rate)?  rateChanged,TResult? Function( String message,  Object? error,  StackTrace? stackTrace)?  error,}) {final _that = this;
switch (_that) {
case PlayerAdapterOpened() when opened != null:
return opened(_that.source);case PlayerAdapterPlaying() when playing != null:
return playing();case PlayerAdapterPaused() when paused != null:
return paused();case PlayerAdapterStopped() when stopped != null:
return stopped();case PlayerAdapterBuffering() when buffering != null:
return buffering(_that.buffering,_that.progress);case PlayerAdapterCompleted() when completed != null:
return completed();case PlayerAdapterPositionChanged() when positionChanged != null:
return positionChanged(_that.position);case PlayerAdapterDurationChanged() when durationChanged != null:
return durationChanged(_that.duration);case PlayerAdapterVideoSizeChanged() when videoSizeChanged != null:
return videoSizeChanged(_that.width,_that.height);case PlayerAdapterVolumeChanged() when volumeChanged != null:
return volumeChanged(_that.volume);case PlayerAdapterRateChanged() when rateChanged != null:
return rateChanged(_that.rate);case PlayerAdapterErrorEvent() when error != null:
return error(_that.message,_that.error,_that.stackTrace);case _:
  return null;

}
}

}

/// @nodoc


class PlayerAdapterOpened implements PlayerAdapterEvent {
  const PlayerAdapterOpened({this.source});
  

/// Opened source identifier.
 final  String? source;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerAdapterOpenedCopyWith<PlayerAdapterOpened> get copyWith => _$PlayerAdapterOpenedCopyWithImpl<PlayerAdapterOpened>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterOpened&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,source);
}

@override
String toString() {
    return 'PlayerAdapterEvent.opened(source: $source)';
}


}

/// @nodoc
abstract mixin class $PlayerAdapterOpenedCopyWith<$Res> implements $PlayerAdapterEventCopyWith<$Res> {
  factory $PlayerAdapterOpenedCopyWith(PlayerAdapterOpened value, $Res Function(PlayerAdapterOpened) _then) = _$PlayerAdapterOpenedCopyWithImpl;
@useResult
$Res call({
 String? source
});




}
/// @nodoc
class _$PlayerAdapterOpenedCopyWithImpl<$Res>
    implements $PlayerAdapterOpenedCopyWith<$Res> {
  _$PlayerAdapterOpenedCopyWithImpl(this._self, this._then);

  final PlayerAdapterOpened _self;
  final $Res Function(PlayerAdapterOpened) _then;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = freezed,}) {
  return _then(PlayerAdapterOpened(
source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class PlayerAdapterPlaying implements PlayerAdapterEvent {
  const PlayerAdapterPlaying();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterPlaying);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PlayerAdapterEvent.playing()';
}


}




/// @nodoc


class PlayerAdapterPaused implements PlayerAdapterEvent {
  const PlayerAdapterPaused();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterPaused);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PlayerAdapterEvent.paused()';
}


}




/// @nodoc


class PlayerAdapterStopped implements PlayerAdapterEvent {
  const PlayerAdapterStopped();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterStopped);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PlayerAdapterEvent.stopped()';
}


}




/// @nodoc


class PlayerAdapterBuffering implements PlayerAdapterEvent {
  const PlayerAdapterBuffering({required this.buffering, this.progress});
  

/// Whether buffering is active.
 final  bool buffering;
/// Optional buffering percentage.
 final  double? progress;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerAdapterBufferingCopyWith<PlayerAdapterBuffering> get copyWith => _$PlayerAdapterBufferingCopyWithImpl<PlayerAdapterBuffering>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterBuffering&&(identical(other.buffering, buffering) || other.buffering == buffering)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode {
    return Object.hash(runtimeType,buffering,progress);
}

@override
String toString() {
    return 'PlayerAdapterEvent.buffering(buffering: $buffering, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $PlayerAdapterBufferingCopyWith<$Res> implements $PlayerAdapterEventCopyWith<$Res> {
  factory $PlayerAdapterBufferingCopyWith(PlayerAdapterBuffering value, $Res Function(PlayerAdapterBuffering) _then) = _$PlayerAdapterBufferingCopyWithImpl;
@useResult
$Res call({
 bool buffering, double? progress
});




}
/// @nodoc
class _$PlayerAdapterBufferingCopyWithImpl<$Res>
    implements $PlayerAdapterBufferingCopyWith<$Res> {
  _$PlayerAdapterBufferingCopyWithImpl(this._self, this._then);

  final PlayerAdapterBuffering _self;
  final $Res Function(PlayerAdapterBuffering) _then;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? buffering = null,Object? progress = freezed,}) {
  return _then(PlayerAdapterBuffering(
buffering: null == buffering ? _self.buffering : buffering // ignore: cast_nullable_to_non_nullable
as bool,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc


class PlayerAdapterCompleted implements PlayerAdapterEvent {
  const PlayerAdapterCompleted();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterCompleted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PlayerAdapterEvent.completed()';
}


}




/// @nodoc


class PlayerAdapterPositionChanged implements PlayerAdapterEvent {
  const PlayerAdapterPositionChanged({required this.position});
  

 final  Duration position;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerAdapterPositionChangedCopyWith<PlayerAdapterPositionChanged> get copyWith => _$PlayerAdapterPositionChangedCopyWithImpl<PlayerAdapterPositionChanged>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterPositionChanged&&(identical(other.position, position) || other.position == position));
}


@override
int get hashCode {
    return Object.hash(runtimeType,position);
}

@override
String toString() {
    return 'PlayerAdapterEvent.positionChanged(position: $position)';
}


}

/// @nodoc
abstract mixin class $PlayerAdapterPositionChangedCopyWith<$Res> implements $PlayerAdapterEventCopyWith<$Res> {
  factory $PlayerAdapterPositionChangedCopyWith(PlayerAdapterPositionChanged value, $Res Function(PlayerAdapterPositionChanged) _then) = _$PlayerAdapterPositionChangedCopyWithImpl;
@useResult
$Res call({
 Duration position
});




}
/// @nodoc
class _$PlayerAdapterPositionChangedCopyWithImpl<$Res>
    implements $PlayerAdapterPositionChangedCopyWith<$Res> {
  _$PlayerAdapterPositionChangedCopyWithImpl(this._self, this._then);

  final PlayerAdapterPositionChanged _self;
  final $Res Function(PlayerAdapterPositionChanged) _then;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? position = null,}) {
  return _then(PlayerAdapterPositionChanged(
position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

/// @nodoc


class PlayerAdapterDurationChanged implements PlayerAdapterEvent {
  const PlayerAdapterDurationChanged({required this.duration});
  

 final  Duration duration;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerAdapterDurationChangedCopyWith<PlayerAdapterDurationChanged> get copyWith => _$PlayerAdapterDurationChangedCopyWithImpl<PlayerAdapterDurationChanged>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterDurationChanged&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode {
    return Object.hash(runtimeType,duration);
}

@override
String toString() {
    return 'PlayerAdapterEvent.durationChanged(duration: $duration)';
}


}

/// @nodoc
abstract mixin class $PlayerAdapterDurationChangedCopyWith<$Res> implements $PlayerAdapterEventCopyWith<$Res> {
  factory $PlayerAdapterDurationChangedCopyWith(PlayerAdapterDurationChanged value, $Res Function(PlayerAdapterDurationChanged) _then) = _$PlayerAdapterDurationChangedCopyWithImpl;
@useResult
$Res call({
 Duration duration
});




}
/// @nodoc
class _$PlayerAdapterDurationChangedCopyWithImpl<$Res>
    implements $PlayerAdapterDurationChangedCopyWith<$Res> {
  _$PlayerAdapterDurationChangedCopyWithImpl(this._self, this._then);

  final PlayerAdapterDurationChanged _self;
  final $Res Function(PlayerAdapterDurationChanged) _then;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? duration = null,}) {
  return _then(PlayerAdapterDurationChanged(
duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

/// @nodoc


class PlayerAdapterVideoSizeChanged implements PlayerAdapterEvent {
  const PlayerAdapterVideoSizeChanged({required this.width, required this.height});
  

 final  int width;
 final  int height;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerAdapterVideoSizeChangedCopyWith<PlayerAdapterVideoSizeChanged> get copyWith => _$PlayerAdapterVideoSizeChangedCopyWithImpl<PlayerAdapterVideoSizeChanged>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterVideoSizeChanged&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode {
    return Object.hash(runtimeType,width,height);
}

@override
String toString() {
    return 'PlayerAdapterEvent.videoSizeChanged(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $PlayerAdapterVideoSizeChangedCopyWith<$Res> implements $PlayerAdapterEventCopyWith<$Res> {
  factory $PlayerAdapterVideoSizeChangedCopyWith(PlayerAdapterVideoSizeChanged value, $Res Function(PlayerAdapterVideoSizeChanged) _then) = _$PlayerAdapterVideoSizeChangedCopyWithImpl;
@useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$PlayerAdapterVideoSizeChangedCopyWithImpl<$Res>
    implements $PlayerAdapterVideoSizeChangedCopyWith<$Res> {
  _$PlayerAdapterVideoSizeChangedCopyWithImpl(this._self, this._then);

  final PlayerAdapterVideoSizeChanged _self;
  final $Res Function(PlayerAdapterVideoSizeChanged) _then;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,}) {
  return _then(PlayerAdapterVideoSizeChanged(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class PlayerAdapterVolumeChanged implements PlayerAdapterEvent {
  const PlayerAdapterVolumeChanged({required this.volume});
  

 final  double volume;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerAdapterVolumeChangedCopyWith<PlayerAdapterVolumeChanged> get copyWith => _$PlayerAdapterVolumeChangedCopyWithImpl<PlayerAdapterVolumeChanged>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterVolumeChanged&&(identical(other.volume, volume) || other.volume == volume));
}


@override
int get hashCode {
    return Object.hash(runtimeType,volume);
}

@override
String toString() {
    return 'PlayerAdapterEvent.volumeChanged(volume: $volume)';
}


}

/// @nodoc
abstract mixin class $PlayerAdapterVolumeChangedCopyWith<$Res> implements $PlayerAdapterEventCopyWith<$Res> {
  factory $PlayerAdapterVolumeChangedCopyWith(PlayerAdapterVolumeChanged value, $Res Function(PlayerAdapterVolumeChanged) _then) = _$PlayerAdapterVolumeChangedCopyWithImpl;
@useResult
$Res call({
 double volume
});




}
/// @nodoc
class _$PlayerAdapterVolumeChangedCopyWithImpl<$Res>
    implements $PlayerAdapterVolumeChangedCopyWith<$Res> {
  _$PlayerAdapterVolumeChangedCopyWithImpl(this._self, this._then);

  final PlayerAdapterVolumeChanged _self;
  final $Res Function(PlayerAdapterVolumeChanged) _then;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? volume = null,}) {
  return _then(PlayerAdapterVolumeChanged(
volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class PlayerAdapterRateChanged implements PlayerAdapterEvent {
  const PlayerAdapterRateChanged({required this.rate});
  

 final  double rate;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerAdapterRateChangedCopyWith<PlayerAdapterRateChanged> get copyWith => _$PlayerAdapterRateChangedCopyWithImpl<PlayerAdapterRateChanged>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterRateChanged&&(identical(other.rate, rate) || other.rate == rate));
}


@override
int get hashCode {
    return Object.hash(runtimeType,rate);
}

@override
String toString() {
    return 'PlayerAdapterEvent.rateChanged(rate: $rate)';
}


}

/// @nodoc
abstract mixin class $PlayerAdapterRateChangedCopyWith<$Res> implements $PlayerAdapterEventCopyWith<$Res> {
  factory $PlayerAdapterRateChangedCopyWith(PlayerAdapterRateChanged value, $Res Function(PlayerAdapterRateChanged) _then) = _$PlayerAdapterRateChangedCopyWithImpl;
@useResult
$Res call({
 double rate
});




}
/// @nodoc
class _$PlayerAdapterRateChangedCopyWithImpl<$Res>
    implements $PlayerAdapterRateChangedCopyWith<$Res> {
  _$PlayerAdapterRateChangedCopyWithImpl(this._self, this._then);

  final PlayerAdapterRateChanged _self;
  final $Res Function(PlayerAdapterRateChanged) _then;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? rate = null,}) {
  return _then(PlayerAdapterRateChanged(
rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class PlayerAdapterErrorEvent implements PlayerAdapterEvent {
  const PlayerAdapterErrorEvent({required this.message, this.error, this.stackTrace});
  

 final  String message;
 final  Object? error;
 final  StackTrace? stackTrace;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerAdapterErrorEventCopyWith<PlayerAdapterErrorEvent> get copyWith => _$PlayerAdapterErrorEventCopyWithImpl<PlayerAdapterErrorEvent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerAdapterErrorEvent&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.stackTrace, stackTrace) || other.stackTrace == stackTrace));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message,const DeepCollectionEquality().hash(error),stackTrace);
}

@override
String toString() {
    return 'PlayerAdapterEvent.error(message: $message, error: $error, stackTrace: $stackTrace)';
}


}

/// @nodoc
abstract mixin class $PlayerAdapterErrorEventCopyWith<$Res> implements $PlayerAdapterEventCopyWith<$Res> {
  factory $PlayerAdapterErrorEventCopyWith(PlayerAdapterErrorEvent value, $Res Function(PlayerAdapterErrorEvent) _then) = _$PlayerAdapterErrorEventCopyWithImpl;
@useResult
$Res call({
 String message, Object? error, StackTrace? stackTrace
});




}
/// @nodoc
class _$PlayerAdapterErrorEventCopyWithImpl<$Res>
    implements $PlayerAdapterErrorEventCopyWith<$Res> {
  _$PlayerAdapterErrorEventCopyWithImpl(this._self, this._then);

  final PlayerAdapterErrorEvent _self;
  final $Res Function(PlayerAdapterErrorEvent) _then;

/// Create a copy of PlayerAdapterEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,Object? error = freezed,Object? stackTrace = freezed,}) {
  return _then(PlayerAdapterErrorEvent(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error ,stackTrace: freezed == stackTrace ? _self.stackTrace : stackTrace // ignore: cast_nullable_to_non_nullable
as StackTrace?,
  ));
}


}

// dart format on
