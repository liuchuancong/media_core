/// Public library for the `models/resource` module.
///
/// What the resource subsystem declares and reports: the bandwidth
/// limits it works to, the pressure it observed, the counters it measured,
/// the state those add up to, and the snapshot it hands to observers.
library;

export 'package:media_core/src/models/resource/bandwidth_budget.dart';
export 'package:media_core/src/models/resource/resource_metrics.dart';
export 'package:media_core/src/models/resource/resource_pressure_snapshot.dart';
export 'package:media_core/src/models/resource/resource_snapshot.dart';
export 'package:media_core/src/models/resource/resource_state.dart';
