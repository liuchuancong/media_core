/// Public library for the `models/presentation` module.
///
/// What the presentation subsystem reports about itself right now: the mode
/// it settled in, the mode it is heading to, the per-mode fullscreen, floating
/// and PiP lifecycles, and whether anything is in flight or has failed.
library;

export 'package:media_core/src/models/presentation/floating_state.dart';
export 'package:media_core/src/models/presentation/fullscreen_state.dart';
export 'package:media_core/src/models/presentation/pip_state.dart';
export 'package:media_core/src/models/presentation/presentation_snapshot.dart';
export 'package:media_core/src/models/presentation/presentation_state.dart';
