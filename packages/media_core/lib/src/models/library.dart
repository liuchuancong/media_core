/// Public library for the `models` module.
///
/// The immutable value objects the core passes around, grouped by what they
/// describe rather than by the service that produces them, so a model can be
/// read without opening the layer that happens to build it.
library;

export 'package:media_core/src/models/audio/library.dart';
export 'package:media_core/src/models/lifecycle/library.dart';
export 'package:media_core/src/models/network/library.dart';
export 'package:media_core/src/models/platform/library.dart';
export 'package:media_core/src/models/pool/library.dart';
export 'package:media_core/src/models/preload/library.dart';
export 'package:media_core/src/models/quality/library.dart';
export 'package:media_core/src/models/reconciler/library.dart';
export 'package:media_core/src/models/resource/library.dart';
export 'package:media_core/src/models/session/library.dart';
export 'package:media_core/src/models/slot/library.dart';
export 'package:media_core/src/models/source/library.dart';
export 'package:media_core/src/models/thumbnail/library.dart';
export 'package:media_core/src/models/timeline/library.dart';
export 'package:media_core/src/models/visibility/library.dart';
