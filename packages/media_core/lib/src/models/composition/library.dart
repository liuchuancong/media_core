/// Public library for the `models/composition` module.
///
/// What an author places on a channel's clock and what cuts into it: a
/// duration-typed clip with a role, and the group of clips that forms one
/// interruption at one program position. The placement engine's own
/// coordinates live beside these as the family grows.
library;

export 'package:media_core/src/models/composition/clip_kind.dart';
export 'package:media_core/src/models/composition/media_break.dart';
export 'package:media_core/src/models/composition/schedule_clip.dart';
