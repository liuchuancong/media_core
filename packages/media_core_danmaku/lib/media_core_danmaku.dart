/// Danmaku sessions: platform-agnostic transport contract, message
/// normalization, backlog/duplicate gating, content filtering and the session
/// lifecycle that keeps an old socket from writing into a new room.
///
/// Platform protocols live in adapter packages and implement
/// [DanmakuTransport]; rendering, queueing and translation live in the host,
/// which implements [DanmakuSink]. Neither is known to this package.
library;

export 'src/danmaku_config.dart';
export 'src/danmaku_controller.dart';
export 'src/danmaku_failure.dart';
export 'src/danmaku_fanout_sink.dart';
export 'src/danmaku_filter_policy.dart';
export 'src/danmaku_message.dart';
export 'src/danmaku_message_gate.dart';
export 'src/danmaku_overlay_config.dart';
export 'src/danmaku_overlay_session.dart';
export 'src/danmaku_repeated_filter.dart';
export 'src/danmaku_session_state.dart';
export 'src/danmaku_similarity_filter.dart';
export 'src/danmaku_sink.dart';
export 'src/danmaku_transport.dart';
