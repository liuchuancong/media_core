import 'package:built_value/built_value.dart';
import 'package:media_core_danmaku/src/model/danmaku_failure.dart';
import 'package:media_core_danmaku/src/model/danmaku_session_phase.dart';

part 'danmaku_session_state.g.dart';

/// Immutable snapshot of a danmaku session.
///
/// Responsibilities:
///
/// - report the lifecycle phase
/// - identify the room and transport the phase belongs to
/// - expose the last failure
///
/// It does not:
///
/// - connect or disconnect anything
/// - hold messages
/// - decide when to reconnect
///
/// Those responsibilities belong to:
///
/// - DanmakuController
/// - DanmakuTransport
abstract class DanmakuSessionState implements Built<DanmakuSessionState, DanmakuSessionStateBuilder> {
  /// Builds DanmakuSessionState from a [updates] callback — the codegen entry.
  factory DanmakuSessionState([void Function(DanmakuSessionStateBuilder)? updates]) = _$DanmakuSessionState;

  /// A snapshot, defaulting to the idle phase with nothing installed.
  factory DanmakuSessionState.of({
    DanmakuSessionPhase phase = DanmakuSessionPhase.idle,
    String? roomKey,
    String? roomId,
    String? platform,
    String? transportId,
    int generation = 0,
    DanmakuFailure? failure,
    bool installed = false,
  }) {
    return DanmakuSessionState(
      (builder) => builder
        ..phase = phase
        ..roomKey = roomKey
        ..roomId = roomId
        ..platform = platform
        ..transportId = transportId
        ..generation = generation
        ..failure = failure
        ..installed = installed,
    );
  }

  DanmakuSessionState._();

  /// A session starts idle, at generation zero, with no room, no transport and
  /// nothing installed yet.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(DanmakuSessionStateBuilder builder) => builder
    ..phase = DanmakuSessionPhase.idle
    ..generation = 0
    ..installed = false;

  /// The lifecycle phase captured in this snapshot.
  DanmakuSessionPhase get phase;

  /// Session key of the room this snapshot describes, when one is owned.
  String? get roomKey;

  /// Platform room id, when one is known. Not the local session key: hosts
  /// display this one.
  String? get roomId;

  /// Platform identifier the room belongs to, when known.
  String? get platform;

  /// Transport identifier currently installed.
  String? get transportId;

  /// Increments for every accepted session. Lets a host drop events that
  /// belong to a session it has already moved on from.
  int get generation;

  /// Last failure, cleared when a new session is accepted.
  DanmakuFailure? get failure;

  /// Whether a transport has been installed at all.
  ///
  /// A controller with no transport cannot connect, and a host must not treat
  /// that as an error: several platforms have no chat integration, and the
  /// caller simply never installs one.
  bool get installed;

  /// Whether the session's transport is attached and delivering.
  bool get isConnected => phase == DanmakuSessionPhase.connected;

  /// Whether a handshake is currently in flight.
  bool get isConnecting => phase == DanmakuSessionPhase.connecting;

  /// Whether anything currently owns the room.
  bool get ownsRoom => roomKey != null && phase != DanmakuSessionPhase.closed && phase != DanmakuSessionPhase.failed;

  /// A copy with the given fields replaced; an omitted field keeps its current
  /// value and [clearFailure] / [clearRoom] drop values instead of replacing
  /// them, which is the reading every controller call site already relies on.
  DanmakuSessionState copyWith({
    DanmakuSessionPhase? phase,
    String? roomKey,
    String? roomId,
    String? platform,
    String? transportId,
    int? generation,
    DanmakuFailure? failure,
    bool? installed,
    bool clearFailure = false,
    bool clearRoom = false,
  }) {
    return rebuild((builder) {
      builder
        ..phase = phase ?? builder.phase
        ..transportId = transportId ?? builder.transportId
        ..generation = generation ?? builder.generation
        ..installed = installed ?? builder.installed
        ..failure = clearFailure ? null : (failure ?? builder.failure);

      if (clearRoom) {
        builder
          ..roomKey = null
          ..roomId = null
          ..platform = null;
      } else {
        builder
          ..roomKey = roomKey ?? builder.roomKey
          ..roomId = roomId ?? builder.roomId
          ..platform = platform ?? builder.platform;
      }
    });
  }
}
