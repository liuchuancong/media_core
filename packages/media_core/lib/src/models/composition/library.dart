/// Public library for the `models/composition` module.
///
/// What an author places on a channel's clock and what cuts into it: a
/// duration-typed clip with a role, the group of clips that forms one
/// interruption at one program position, the schedule that binds them, and
/// the coordinates the placement engine gives them once they are on the
/// combined clock.
library;

export 'package:media_core/src/models/composition/clip_kind.dart';
export 'package:media_core/src/models/composition/composed_schedule.dart';
export 'package:media_core/src/models/composition/media_break.dart';
export 'package:media_core/src/models/composition/playback_schedule.dart';
export 'package:media_core/src/models/composition/schedule_clip.dart';
export 'package:media_core/src/models/composition/schedule_position.dart';
export 'package:media_core/src/models/composition/scheduled_segment.dart';
