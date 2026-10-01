import 'package:freezed_annotation/freezed_annotation.dart';

/// The lifecycle state of a player.
@JsonEnum()
enum PlayerLifecycleState { idle, initializing, ready, disposing, disposed }
