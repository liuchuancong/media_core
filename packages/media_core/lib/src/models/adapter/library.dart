/// Public library for the `models/adapter` module.
///
/// What a backend adapter is handed, what it reports while it runs, and what
/// it answers with when it fails: the configuration, the identity-and-platform
/// context around one adapter, the state snapshot, and the normalized error.
library;

export 'package:media_core/src/models/adapter/player_adapter_config.dart';
export 'package:media_core/src/models/adapter/player_adapter_context.dart';
export 'package:media_core/src/models/adapter/player_adapter_error.dart';
export 'package:media_core/src/models/adapter/player_adapter_error_type.dart';
export 'package:media_core/src/models/adapter/player_adapter_state.dart';
