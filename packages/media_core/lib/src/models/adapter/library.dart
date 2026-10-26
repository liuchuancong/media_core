/// Public library for the `models/adapter` module.
///
/// What a backend adapter is handed and what it reports back when it fails:
/// the configuration, the identity-and-platform context around one adapter,
/// and the normalized error a backend produces.
library;

export 'package:media_core/src/models/adapter/player_adapter_config.dart';
export 'package:media_core/src/models/adapter/player_adapter_context.dart';
export 'package:media_core/src/models/adapter/player_adapter_error.dart';
export 'package:media_core/src/models/adapter/player_adapter_error_type.dart';
