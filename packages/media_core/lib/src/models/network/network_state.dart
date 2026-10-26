import 'package:built_value/built_value.dart';
import 'package:media_core/src/models/network/network_quality.dart';
import 'package:media_core/src/models/network/network_type.dart';
import 'package:media_core/src/network/monitor/network_manager.dart';
import 'package:media_core/src/network/monitor/network_monitor.dart';

part 'network_state.g.dart';

/// Represents current network state.
///
/// This is an immutable snapshot describing
/// the current network environment.
///
/// Responsibilities:
///
/// - store current network type
/// - store network quality
/// - represent connectivity availability
/// - provide immutable state updates
///
/// It does not:
///
/// - monitor network changes
/// - perform network requests
/// - manage listeners
///
/// Those belong to:
///
/// - [NetworkMonitor]
/// - [NetworkManager]
abstract class NetworkState implements Built<NetworkState, NetworkStateBuilder> {
  /// Builds a state from a [updates] callback — the codegen entry.
  factory NetworkState([void Function(NetworkStateBuilder)? updates]) = _$NetworkState;

  /// Creates a network state.
  factory NetworkState.of({
    bool connected = false,
    NetworkType type = NetworkType.unknown,
    NetworkQuality quality = NetworkQuality.unknown,
    bool metered = false,
    bool expensive = false,
    DateTime? updatedAt,
  }) {
    return NetworkState(
      (builder) => builder
        ..connected = connected
        ..type = type
        ..quality = quality
        ..metered = metered
        ..expensive = expensive
        ..updatedAt = updatedAt,
    );
  }

  NetworkState._();

  /// Creates an initial unknown network state.
  factory NetworkState.initial() => NetworkState.of();

  /// The monitor has not reported anything until it says so, and an
  /// unreported network is neither connected, metered nor expensive.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(NetworkStateBuilder builder) => builder
    ..connected = false
    ..type = NetworkType.unknown
    ..quality = NetworkQuality.unknown
    ..metered = false
    ..expensive = false;

  /// Whether network connection is available.
  bool get connected;

  /// Current network type.
  NetworkType get type;

  /// Current network quality.
  NetworkQuality get quality;

  /// Whether the network is metered.
  ///
  /// Examples:
  /// - mobile data
  /// - restricted hotspot
  bool get metered;

  /// Whether network is considered expensive.
  bool get expensive;

  /// Last update timestamp.
  DateTime? get updatedAt;
}
