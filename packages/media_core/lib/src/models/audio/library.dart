/// Public library for the `models/audio` module.
///
/// What the audio subsystem reports about itself: the output route a
/// session is playing through, and the focus and session lifecycle
/// snapshots a coordinator publishes, together with the statuses those
/// two can take.
library;

export 'package:media_core/src/models/audio/audio_focus_state.dart';
export 'package:media_core/src/models/audio/audio_focus_status.dart';
export 'package:media_core/src/models/audio/audio_route.dart';
export 'package:media_core/src/models/audio/audio_route_kind.dart';
export 'package:media_core/src/models/audio/audio_session_state.dart';
export 'package:media_core/src/models/audio/audio_session_status.dart';
