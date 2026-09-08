// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlayerState {

/// Whether the player has been initialized.
 bool get initialized;/// Whether the player is currently opening a source.
 bool get opening;/// Whether the player is ready for playback.
 bool get ready;/// Whether the player is currently playing.
 bool get playing;/// Whether playback is currently paused.
 bool get paused;/// Whether the player is currently buffering.
 bool get buffering;/// Whether the player is currently seeking.
 bool get seeking;/// Whether the player is currently stopping.
 bool get stopping;/// Whether the player has stopped playback.
 bool get stopped;/// Whether playback reached the end of the current media.
 bool get completed;/// Whether the player is being disposed.
 bool get disposing;/// Whether the player has been disposed.
 bool get disposed;/// Whether a media source is currently associated with the player.
 bool get hasSource;/// Whether the player currently contains an error.
 bool get hasError;/// Whether audio output is muted.
 bool get muted;/// Whether audio output is enabled.
 bool get audioEnabled;/// Whether video output is enabled.
 bool get videoEnabled;/// Whether subtitle output is enabled.
 bool get subtitlesEnabled;/// Whether the player is currently in fullscreen presentation.
 bool get fullscreen;/// Whether the player is currently in picture-in-picture mode.
 bool get pip;/// Whether the player is currently displayed in a floating mode.
 bool get floating;/// Whether recording is currently active.
 bool get recording;/// Whether the player is currently recovering from a failure.
 bool get recovering;/// Whether the player is currently switching through a fallback.
 bool get fallingBack;
/// Create a copy of PlayerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerStateCopyWith<PlayerState> get copyWith => _$PlayerStateCopyWithImpl<PlayerState>(this as PlayerState, _$identity);

  /// Serializes this PlayerState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlayerState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerState&&(identical(other.initialized, _this.initialized) || other.initialized == _this.initialized)&&(identical(other.opening, _this.opening) || other.opening == _this.opening)&&(identical(other.ready, _this.ready) || other.ready == _this.ready)&&(identical(other.playing, _this.playing) || other.playing == _this.playing)&&(identical(other.paused, _this.paused) || other.paused == _this.paused)&&(identical(other.buffering, _this.buffering) || other.buffering == _this.buffering)&&(identical(other.seeking, _this.seeking) || other.seeking == _this.seeking)&&(identical(other.stopping, _this.stopping) || other.stopping == _this.stopping)&&(identical(other.stopped, _this.stopped) || other.stopped == _this.stopped)&&(identical(other.completed, _this.completed) || other.completed == _this.completed)&&(identical(other.disposing, _this.disposing) || other.disposing == _this.disposing)&&(identical(other.disposed, _this.disposed) || other.disposed == _this.disposed)&&(identical(other.hasSource, _this.hasSource) || other.hasSource == _this.hasSource)&&(identical(other.hasError, _this.hasError) || other.hasError == _this.hasError)&&(identical(other.muted, _this.muted) || other.muted == _this.muted)&&(identical(other.audioEnabled, _this.audioEnabled) || other.audioEnabled == _this.audioEnabled)&&(identical(other.videoEnabled, _this.videoEnabled) || other.videoEnabled == _this.videoEnabled)&&(identical(other.subtitlesEnabled, _this.subtitlesEnabled) || other.subtitlesEnabled == _this.subtitlesEnabled)&&(identical(other.fullscreen, _this.fullscreen) || other.fullscreen == _this.fullscreen)&&(identical(other.pip, _this.pip) || other.pip == _this.pip)&&(identical(other.floating, _this.floating) || other.floating == _this.floating)&&(identical(other.recording, _this.recording) || other.recording == _this.recording)&&(identical(other.recovering, _this.recovering) || other.recovering == _this.recovering)&&(identical(other.fallingBack, _this.fallingBack) || other.fallingBack == _this.fallingBack));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlayerState;
  return Object.hashAll([runtimeType,_this.initialized,_this.opening,_this.ready,_this.playing,_this.paused,_this.buffering,_this.seeking,_this.stopping,_this.stopped,_this.completed,_this.disposing,_this.disposed,_this.hasSource,_this.hasError,_this.muted,_this.audioEnabled,_this.videoEnabled,_this.subtitlesEnabled,_this.fullscreen,_this.pip,_this.floating,_this.recording,_this.recovering,_this.fallingBack]);
}

@override
String toString() {
  final _this = this as PlayerState;
  return 'PlayerState(initialized: ${_this.initialized}, opening: ${_this.opening}, ready: ${_this.ready}, playing: ${_this.playing}, paused: ${_this.paused}, buffering: ${_this.buffering}, seeking: ${_this.seeking}, stopping: ${_this.stopping}, stopped: ${_this.stopped}, completed: ${_this.completed}, disposing: ${_this.disposing}, disposed: ${_this.disposed}, hasSource: ${_this.hasSource}, hasError: ${_this.hasError}, muted: ${_this.muted}, audioEnabled: ${_this.audioEnabled}, videoEnabled: ${_this.videoEnabled}, subtitlesEnabled: ${_this.subtitlesEnabled}, fullscreen: ${_this.fullscreen}, pip: ${_this.pip}, floating: ${_this.floating}, recording: ${_this.recording}, recovering: ${_this.recovering}, fallingBack: ${_this.fallingBack})';
}


}

/// @nodoc
abstract mixin class $PlayerStateCopyWith<$Res>  {
  factory $PlayerStateCopyWith(PlayerState value, $Res Function(PlayerState) _then) = _$PlayerStateCopyWithImpl;
@useResult
$Res call({
 bool initialized, bool opening, bool ready, bool playing, bool paused, bool buffering, bool seeking, bool stopping, bool stopped, bool completed, bool disposing, bool disposed, bool hasSource, bool hasError, bool muted, bool audioEnabled, bool videoEnabled, bool subtitlesEnabled, bool fullscreen, bool pip, bool floating, bool recording, bool recovering, bool fallingBack
});




}
/// @nodoc
class _$PlayerStateCopyWithImpl<$Res>
    implements $PlayerStateCopyWith<$Res> {
  _$PlayerStateCopyWithImpl(this._self, this._then);

  final PlayerState _self;
  final $Res Function(PlayerState) _then;

/// Create a copy of PlayerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? initialized = null,Object? opening = null,Object? ready = null,Object? playing = null,Object? paused = null,Object? buffering = null,Object? seeking = null,Object? stopping = null,Object? stopped = null,Object? completed = null,Object? disposing = null,Object? disposed = null,Object? hasSource = null,Object? hasError = null,Object? muted = null,Object? audioEnabled = null,Object? videoEnabled = null,Object? subtitlesEnabled = null,Object? fullscreen = null,Object? pip = null,Object? floating = null,Object? recording = null,Object? recovering = null,Object? fallingBack = null,}) {
  return _then(PlayerState(
initialized: null == initialized ? _self.initialized : initialized // ignore: cast_nullable_to_non_nullable
as bool,opening: null == opening ? _self.opening : opening // ignore: cast_nullable_to_non_nullable
as bool,ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,playing: null == playing ? _self.playing : playing // ignore: cast_nullable_to_non_nullable
as bool,paused: null == paused ? _self.paused : paused // ignore: cast_nullable_to_non_nullable
as bool,buffering: null == buffering ? _self.buffering : buffering // ignore: cast_nullable_to_non_nullable
as bool,seeking: null == seeking ? _self.seeking : seeking // ignore: cast_nullable_to_non_nullable
as bool,stopping: null == stopping ? _self.stopping : stopping // ignore: cast_nullable_to_non_nullable
as bool,stopped: null == stopped ? _self.stopped : stopped // ignore: cast_nullable_to_non_nullable
as bool,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,disposing: null == disposing ? _self.disposing : disposing // ignore: cast_nullable_to_non_nullable
as bool,disposed: null == disposed ? _self.disposed : disposed // ignore: cast_nullable_to_non_nullable
as bool,hasSource: null == hasSource ? _self.hasSource : hasSource // ignore: cast_nullable_to_non_nullable
as bool,hasError: null == hasError ? _self.hasError : hasError // ignore: cast_nullable_to_non_nullable
as bool,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,audioEnabled: null == audioEnabled ? _self.audioEnabled : audioEnabled // ignore: cast_nullable_to_non_nullable
as bool,videoEnabled: null == videoEnabled ? _self.videoEnabled : videoEnabled // ignore: cast_nullable_to_non_nullable
as bool,subtitlesEnabled: null == subtitlesEnabled ? _self.subtitlesEnabled : subtitlesEnabled // ignore: cast_nullable_to_non_nullable
as bool,fullscreen: null == fullscreen ? _self.fullscreen : fullscreen // ignore: cast_nullable_to_non_nullable
as bool,pip: null == pip ? _self.pip : pip // ignore: cast_nullable_to_non_nullable
as bool,floating: null == floating ? _self.floating : floating // ignore: cast_nullable_to_non_nullable
as bool,recording: null == recording ? _self.recording : recording // ignore: cast_nullable_to_non_nullable
as bool,recovering: null == recovering ? _self.recovering : recovering // ignore: cast_nullable_to_non_nullable
as bool,fallingBack: null == fallingBack ? _self.fallingBack : fallingBack // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PlayerState].
extension PlayerStatePatterns on PlayerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerState value)  $default,){
final _that = this;
switch (_that) {
case _PlayerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerState value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool initialized,  bool opening,  bool ready,  bool playing,  bool paused,  bool buffering,  bool seeking,  bool stopping,  bool stopped,  bool completed,  bool disposing,  bool disposed,  bool hasSource,  bool hasError,  bool muted,  bool audioEnabled,  bool videoEnabled,  bool subtitlesEnabled,  bool fullscreen,  bool pip,  bool floating,  bool recording,  bool recovering,  bool fallingBack)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerState() when $default != null:
return $default(_that.initialized,_that.opening,_that.ready,_that.playing,_that.paused,_that.buffering,_that.seeking,_that.stopping,_that.stopped,_that.completed,_that.disposing,_that.disposed,_that.hasSource,_that.hasError,_that.muted,_that.audioEnabled,_that.videoEnabled,_that.subtitlesEnabled,_that.fullscreen,_that.pip,_that.floating,_that.recording,_that.recovering,_that.fallingBack);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool initialized,  bool opening,  bool ready,  bool playing,  bool paused,  bool buffering,  bool seeking,  bool stopping,  bool stopped,  bool completed,  bool disposing,  bool disposed,  bool hasSource,  bool hasError,  bool muted,  bool audioEnabled,  bool videoEnabled,  bool subtitlesEnabled,  bool fullscreen,  bool pip,  bool floating,  bool recording,  bool recovering,  bool fallingBack)  $default,) {final _that = this;
switch (_that) {
case _PlayerState():
return $default(_that.initialized,_that.opening,_that.ready,_that.playing,_that.paused,_that.buffering,_that.seeking,_that.stopping,_that.stopped,_that.completed,_that.disposing,_that.disposed,_that.hasSource,_that.hasError,_that.muted,_that.audioEnabled,_that.videoEnabled,_that.subtitlesEnabled,_that.fullscreen,_that.pip,_that.floating,_that.recording,_that.recovering,_that.fallingBack);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool initialized,  bool opening,  bool ready,  bool playing,  bool paused,  bool buffering,  bool seeking,  bool stopping,  bool stopped,  bool completed,  bool disposing,  bool disposed,  bool hasSource,  bool hasError,  bool muted,  bool audioEnabled,  bool videoEnabled,  bool subtitlesEnabled,  bool fullscreen,  bool pip,  bool floating,  bool recording,  bool recovering,  bool fallingBack)?  $default,) {final _that = this;
switch (_that) {
case _PlayerState() when $default != null:
return $default(_that.initialized,_that.opening,_that.ready,_that.playing,_that.paused,_that.buffering,_that.seeking,_that.stopping,_that.stopped,_that.completed,_that.disposing,_that.disposed,_that.hasSource,_that.hasError,_that.muted,_that.audioEnabled,_that.videoEnabled,_that.subtitlesEnabled,_that.fullscreen,_that.pip,_that.floating,_that.recording,_that.recovering,_that.fallingBack);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlayerState extends PlayerState {
  const _PlayerState({this.initialized = false, this.opening = false, this.ready = false, this.playing = false, this.paused = false, this.buffering = false, this.seeking = false, this.stopping = false, this.stopped = false, this.completed = false, this.disposing = false, this.disposed = false, this.hasSource = false, this.hasError = false, this.muted = false, this.audioEnabled = false, this.videoEnabled = false, this.subtitlesEnabled = false, this.fullscreen = false, this.pip = false, this.floating = false, this.recording = false, this.recovering = false, this.fallingBack = false}): super._();
  factory _PlayerState.fromJson(Map<String, dynamic> json) => _$PlayerStateFromJson(json);

/// Whether the player has been initialized.
@override@JsonKey() final  bool initialized;
/// Whether the player is currently opening a source.
@override@JsonKey() final  bool opening;
/// Whether the player is ready for playback.
@override@JsonKey() final  bool ready;
/// Whether the player is currently playing.
@override@JsonKey() final  bool playing;
/// Whether playback is currently paused.
@override@JsonKey() final  bool paused;
/// Whether the player is currently buffering.
@override@JsonKey() final  bool buffering;
/// Whether the player is currently seeking.
@override@JsonKey() final  bool seeking;
/// Whether the player is currently stopping.
@override@JsonKey() final  bool stopping;
/// Whether the player has stopped playback.
@override@JsonKey() final  bool stopped;
/// Whether playback reached the end of the current media.
@override@JsonKey() final  bool completed;
/// Whether the player is being disposed.
@override@JsonKey() final  bool disposing;
/// Whether the player has been disposed.
@override@JsonKey() final  bool disposed;
/// Whether a media source is currently associated with the player.
@override@JsonKey() final  bool hasSource;
/// Whether the player currently contains an error.
@override@JsonKey() final  bool hasError;
/// Whether audio output is muted.
@override@JsonKey() final  bool muted;
/// Whether audio output is enabled.
@override@JsonKey() final  bool audioEnabled;
/// Whether video output is enabled.
@override@JsonKey() final  bool videoEnabled;
/// Whether subtitle output is enabled.
@override@JsonKey() final  bool subtitlesEnabled;
/// Whether the player is currently in fullscreen presentation.
@override@JsonKey() final  bool fullscreen;
/// Whether the player is currently in picture-in-picture mode.
@override@JsonKey() final  bool pip;
/// Whether the player is currently displayed in a floating mode.
@override@JsonKey() final  bool floating;
/// Whether recording is currently active.
@override@JsonKey() final  bool recording;
/// Whether the player is currently recovering from a failure.
@override@JsonKey() final  bool recovering;
/// Whether the player is currently switching through a fallback.
@override@JsonKey() final  bool fallingBack;

/// Create a copy of PlayerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerStateCopyWith<_PlayerState> get copyWith => __$PlayerStateCopyWithImpl<_PlayerState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlayerStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerState&&(identical(other.initialized, initialized) || other.initialized == initialized)&&(identical(other.opening, opening) || other.opening == opening)&&(identical(other.ready, ready) || other.ready == ready)&&(identical(other.playing, playing) || other.playing == playing)&&(identical(other.paused, paused) || other.paused == paused)&&(identical(other.buffering, buffering) || other.buffering == buffering)&&(identical(other.seeking, seeking) || other.seeking == seeking)&&(identical(other.stopping, stopping) || other.stopping == stopping)&&(identical(other.stopped, stopped) || other.stopped == stopped)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.disposing, disposing) || other.disposing == disposing)&&(identical(other.disposed, disposed) || other.disposed == disposed)&&(identical(other.hasSource, hasSource) || other.hasSource == hasSource)&&(identical(other.hasError, hasError) || other.hasError == hasError)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.audioEnabled, audioEnabled) || other.audioEnabled == audioEnabled)&&(identical(other.videoEnabled, videoEnabled) || other.videoEnabled == videoEnabled)&&(identical(other.subtitlesEnabled, subtitlesEnabled) || other.subtitlesEnabled == subtitlesEnabled)&&(identical(other.fullscreen, fullscreen) || other.fullscreen == fullscreen)&&(identical(other.pip, pip) || other.pip == pip)&&(identical(other.floating, floating) || other.floating == floating)&&(identical(other.recording, recording) || other.recording == recording)&&(identical(other.recovering, recovering) || other.recovering == recovering)&&(identical(other.fallingBack, fallingBack) || other.fallingBack == fallingBack));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,initialized,opening,ready,playing,paused,buffering,seeking,stopping,stopped,completed,disposing,disposed,hasSource,hasError,muted,audioEnabled,videoEnabled,subtitlesEnabled,fullscreen,pip,floating,recording,recovering,fallingBack]);
}

@override
String toString() {
    return 'PlayerState(initialized: $initialized, opening: $opening, ready: $ready, playing: $playing, paused: $paused, buffering: $buffering, seeking: $seeking, stopping: $stopping, stopped: $stopped, completed: $completed, disposing: $disposing, disposed: $disposed, hasSource: $hasSource, hasError: $hasError, muted: $muted, audioEnabled: $audioEnabled, videoEnabled: $videoEnabled, subtitlesEnabled: $subtitlesEnabled, fullscreen: $fullscreen, pip: $pip, floating: $floating, recording: $recording, recovering: $recovering, fallingBack: $fallingBack)';
}


}

/// @nodoc
abstract mixin class _$PlayerStateCopyWith<$Res> implements $PlayerStateCopyWith<$Res> {
  factory _$PlayerStateCopyWith(_PlayerState value, $Res Function(_PlayerState) _then) = __$PlayerStateCopyWithImpl;
@override @useResult
$Res call({
 bool initialized, bool opening, bool ready, bool playing, bool paused, bool buffering, bool seeking, bool stopping, bool stopped, bool completed, bool disposing, bool disposed, bool hasSource, bool hasError, bool muted, bool audioEnabled, bool videoEnabled, bool subtitlesEnabled, bool fullscreen, bool pip, bool floating, bool recording, bool recovering, bool fallingBack
});




}
/// @nodoc
class __$PlayerStateCopyWithImpl<$Res>
    implements _$PlayerStateCopyWith<$Res> {
  __$PlayerStateCopyWithImpl(this._self, this._then);

  final _PlayerState _self;
  final $Res Function(_PlayerState) _then;

/// Create a copy of PlayerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? initialized = null,Object? opening = null,Object? ready = null,Object? playing = null,Object? paused = null,Object? buffering = null,Object? seeking = null,Object? stopping = null,Object? stopped = null,Object? completed = null,Object? disposing = null,Object? disposed = null,Object? hasSource = null,Object? hasError = null,Object? muted = null,Object? audioEnabled = null,Object? videoEnabled = null,Object? subtitlesEnabled = null,Object? fullscreen = null,Object? pip = null,Object? floating = null,Object? recording = null,Object? recovering = null,Object? fallingBack = null,}) {
  return _then(_PlayerState(
initialized: null == initialized ? _self.initialized : initialized // ignore: cast_nullable_to_non_nullable
as bool,opening: null == opening ? _self.opening : opening // ignore: cast_nullable_to_non_nullable
as bool,ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,playing: null == playing ? _self.playing : playing // ignore: cast_nullable_to_non_nullable
as bool,paused: null == paused ? _self.paused : paused // ignore: cast_nullable_to_non_nullable
as bool,buffering: null == buffering ? _self.buffering : buffering // ignore: cast_nullable_to_non_nullable
as bool,seeking: null == seeking ? _self.seeking : seeking // ignore: cast_nullable_to_non_nullable
as bool,stopping: null == stopping ? _self.stopping : stopping // ignore: cast_nullable_to_non_nullable
as bool,stopped: null == stopped ? _self.stopped : stopped // ignore: cast_nullable_to_non_nullable
as bool,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,disposing: null == disposing ? _self.disposing : disposing // ignore: cast_nullable_to_non_nullable
as bool,disposed: null == disposed ? _self.disposed : disposed // ignore: cast_nullable_to_non_nullable
as bool,hasSource: null == hasSource ? _self.hasSource : hasSource // ignore: cast_nullable_to_non_nullable
as bool,hasError: null == hasError ? _self.hasError : hasError // ignore: cast_nullable_to_non_nullable
as bool,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,audioEnabled: null == audioEnabled ? _self.audioEnabled : audioEnabled // ignore: cast_nullable_to_non_nullable
as bool,videoEnabled: null == videoEnabled ? _self.videoEnabled : videoEnabled // ignore: cast_nullable_to_non_nullable
as bool,subtitlesEnabled: null == subtitlesEnabled ? _self.subtitlesEnabled : subtitlesEnabled // ignore: cast_nullable_to_non_nullable
as bool,fullscreen: null == fullscreen ? _self.fullscreen : fullscreen // ignore: cast_nullable_to_non_nullable
as bool,pip: null == pip ? _self.pip : pip // ignore: cast_nullable_to_non_nullable
as bool,floating: null == floating ? _self.floating : floating // ignore: cast_nullable_to_non_nullable
as bool,recording: null == recording ? _self.recording : recording // ignore: cast_nullable_to_non_nullable
as bool,recovering: null == recovering ? _self.recovering : recovering // ignore: cast_nullable_to_non_nullable
as bool,fallingBack: null == fallingBack ? _self.fallingBack : fallingBack // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
