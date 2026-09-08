// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlayerState _$PlayerStateFromJson(Map<String, dynamic> json) => _PlayerState(
  initialized: json['initialized'] as bool? ?? false,
  opening: json['opening'] as bool? ?? false,
  ready: json['ready'] as bool? ?? false,
  playing: json['playing'] as bool? ?? false,
  paused: json['paused'] as bool? ?? false,
  buffering: json['buffering'] as bool? ?? false,
  seeking: json['seeking'] as bool? ?? false,
  stopping: json['stopping'] as bool? ?? false,
  stopped: json['stopped'] as bool? ?? false,
  completed: json['completed'] as bool? ?? false,
  disposing: json['disposing'] as bool? ?? false,
  disposed: json['disposed'] as bool? ?? false,
  hasSource: json['hasSource'] as bool? ?? false,
  hasError: json['hasError'] as bool? ?? false,
  muted: json['muted'] as bool? ?? false,
  audioEnabled: json['audioEnabled'] as bool? ?? false,
  videoEnabled: json['videoEnabled'] as bool? ?? false,
  subtitlesEnabled: json['subtitlesEnabled'] as bool? ?? false,
  fullscreen: json['fullscreen'] as bool? ?? false,
  pip: json['pip'] as bool? ?? false,
  floating: json['floating'] as bool? ?? false,
  recording: json['recording'] as bool? ?? false,
  recovering: json['recovering'] as bool? ?? false,
  fallingBack: json['fallingBack'] as bool? ?? false,
);

Map<String, dynamic> _$PlayerStateToJson(_PlayerState instance) =>
    <String, dynamic>{
      'initialized': instance.initialized,
      'opening': instance.opening,
      'ready': instance.ready,
      'playing': instance.playing,
      'paused': instance.paused,
      'buffering': instance.buffering,
      'seeking': instance.seeking,
      'stopping': instance.stopping,
      'stopped': instance.stopped,
      'completed': instance.completed,
      'disposing': instance.disposing,
      'disposed': instance.disposed,
      'hasSource': instance.hasSource,
      'hasError': instance.hasError,
      'muted': instance.muted,
      'audioEnabled': instance.audioEnabled,
      'videoEnabled': instance.videoEnabled,
      'subtitlesEnabled': instance.subtitlesEnabled,
      'fullscreen': instance.fullscreen,
      'pip': instance.pip,
      'floating': instance.floating,
      'recording': instance.recording,
      'recovering': instance.recovering,
      'fallingBack': instance.fallingBack,
    };
