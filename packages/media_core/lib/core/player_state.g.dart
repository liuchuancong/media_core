// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlayerState _$PlayerStateFromJson(Map<String, dynamic> json) => _PlayerState(
  lifecycle:
      $enumDecodeNullable(_$PlayerLifecycleStateEnumMap, json['lifecycle']) ??
      PlayerLifecycleState.idle,
  playback:
      $enumDecodeNullable(_$PlayerPlaybackStateEnumMap, json['playback']) ??
      PlayerPlaybackState.idle,
  hasSource: json['hasSource'] as bool? ?? false,
  audioEnabled: json['audioEnabled'] as bool? ?? false,
  videoEnabled: json['videoEnabled'] as bool? ?? false,
  subtitlesEnabled: json['subtitlesEnabled'] as bool? ?? false,
  muted: json['muted'] as bool? ?? false,
  fullscreen: json['fullscreen'] as bool? ?? false,
  pip: json['pip'] as bool? ?? false,
  floating: json['floating'] as bool? ?? false,
  recording: json['recording'] as bool? ?? false,
  recovering: json['recovering'] as bool? ?? false,
  fallingBack: json['fallingBack'] as bool? ?? false,
);

Map<String, dynamic> _$PlayerStateToJson(_PlayerState instance) =>
    <String, dynamic>{
      'lifecycle': _$PlayerLifecycleStateEnumMap[instance.lifecycle]!,
      'playback': _$PlayerPlaybackStateEnumMap[instance.playback]!,
      'hasSource': instance.hasSource,
      'audioEnabled': instance.audioEnabled,
      'videoEnabled': instance.videoEnabled,
      'subtitlesEnabled': instance.subtitlesEnabled,
      'muted': instance.muted,
      'fullscreen': instance.fullscreen,
      'pip': instance.pip,
      'floating': instance.floating,
      'recording': instance.recording,
      'recovering': instance.recovering,
      'fallingBack': instance.fallingBack,
    };

const _$PlayerLifecycleStateEnumMap = {
  PlayerLifecycleState.idle: 'idle',
  PlayerLifecycleState.initializing: 'initializing',
  PlayerLifecycleState.ready: 'ready',
  PlayerLifecycleState.disposing: 'disposing',
  PlayerLifecycleState.disposed: 'disposed',
};

const _$PlayerPlaybackStateEnumMap = {
  PlayerPlaybackState.idle: 'idle',
  PlayerPlaybackState.opening: 'opening',
  PlayerPlaybackState.playing: 'playing',
  PlayerPlaybackState.paused: 'paused',
  PlayerPlaybackState.buffering: 'buffering',
  PlayerPlaybackState.seeking: 'seeking',
  PlayerPlaybackState.stopping: 'stopping',
  PlayerPlaybackState.stopped: 'stopped',
  PlayerPlaybackState.completed: 'completed',
  PlayerPlaybackState.error: 'error',
};
