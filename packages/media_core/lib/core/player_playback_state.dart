import 'package:freezed_annotation/freezed_annotation.dart';

/// The semantic playback state of a player.
///
/// This represents what the core believes the player is doing. It is not a
/// backend-specific state.
@JsonEnum()
enum PlayerPlaybackState { idle, opening, playing, paused, buffering, seeking, stopping, stopped, completed, error }
