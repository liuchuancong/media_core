import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/network/network_quality.dart';
import 'package:media_core/src/models/network/network_type.dart';
import 'package:media_core/src/network/monitor/network_manager.dart';
import 'package:media_core/src/network/monitor/network_monitor.dart';

part 'network_condition.g.dart';

/// Represents current network condition.
///
/// A [NetworkCondition] is a snapshot describing
/// the current usable network environment.
///
/// Responsibilities:
///
/// - describe connectivity condition
/// - describe network transport type
/// - describe estimated quality
/// - provide immutable network information
///
/// It does not:
///
/// - detect network changes
/// - measure bandwidth
/// - perform connectivity checks
///
/// Those belong to:
///
/// - [NetworkMonitor]
/// - [NetworkManager]
abstract class NetworkCondition implements Built<NetworkCondition, NetworkConditionBuilder> {
  /// Builds a condition from a [updates] callback — the codegen entry.
  factory NetworkCondition([void Function(NetworkConditionBuilder)? updates]) = _$NetworkCondition;

  /// Creates a network condition.
  factory NetworkCondition.of({
    bool connected = false,
    NetworkType type = NetworkType.unknown,
    NetworkQuality quality = NetworkQuality.unknown,
    int? downloadBandwidth,
    int? uploadBandwidth,
    int? latency,
    bool metered = false,
    bool expensive = false,
    DateTime? timestamp,
  }) {
    return NetworkCondition(
      (builder) => builder
        ..connected = connected
        ..type = type
        ..quality = quality
        ..downloadBandwidth = downloadBandwidth
        ..uploadBandwidth = uploadBandwidth
        ..latency = latency
        ..metered = metered
        ..expensive = expensive
        ..timestamp = timestamp,
    );
  }

  NetworkCondition._();

  /// Creates an unknown network condition.
  factory NetworkCondition.unknown() => NetworkCondition.of();

  /// Nothing is known about a condition the monitor has not reported:
  /// no connection, unknown type and quality, nothing metered or
  /// expensive.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(NetworkConditionBuilder builder) => builder
    ..connected = false
    ..type = NetworkType.unknown
    ..quality = NetworkQuality.unknown
    ..metered = false
    ..expensive = false;

  /// Whether network is available.
  bool get connected;

  /// Current network type.
  NetworkType get type;

  /// Current network quality.
  NetworkQuality get quality;

  /// Estimated download bandwidth in bits per second.
  ///
  /// May be unavailable.
  int? get downloadBandwidth;

  /// Estimated upload bandwidth in bits per second.
  ///
  /// May be unavailable.
  int? get uploadBandwidth;

  /// Network latency in milliseconds.
  ///
  /// May be unavailable.
  int? get latency;

  /// Whether connection is metered.
  bool get metered;

  /// Whether connection is considered expensive.
  bool get expensive;

  /// Time when this condition was created.
  DateTime? get timestamp;
}

/// Extensions for [NetworkCondition].
extension NetworkConditionExtension on NetworkCondition {
  /// Whether this condition can be used.
  bool get isAvailable {
    return connected && quality != NetworkQuality.unavailable;
  }

  /// Whether this is a fast connection.
  bool get isFast {
    return quality == NetworkQuality.good || quality == NetworkQuality.excellent;
  }

  /// Whether latency information exists.
  bool get hasLatency {
    return latency != null;
  }

  /// Whether bandwidth information exists.
  bool get hasBandwidth {
    return downloadBandwidth != null || uploadBandwidth != null;
  }
}
