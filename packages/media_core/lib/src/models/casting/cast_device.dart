import 'package:built_value/built_value.dart';

part 'cast_device.g.dart';

/// A discovered render device a cast can be sent to.
///
/// [CastDevice] is protocol-neutral on purpose: a DLNA DMR, a Chromecast
/// and a future AirPlay receiver all answer to the same shape — an
/// identity, a human name, and an opaque [serviceEndpoints] map the
/// backend that discovered the device understands. Nothing above the
/// backend boundary inspects those endpoints, which is what
/// lets a UI list devices without importing a single protocol type.
///
/// Responsibilities:
///
/// - identify a render target for the controller and the UI
///
/// It does not:
///
/// - carry transport state
/// - expose protocol URLs to callers
///
/// Those belong to:
///
/// - CastController
/// - the backend that produced the device
abstract class CastDevice implements Built<CastDevice, CastDeviceBuilder> {
  /// Builds CastDevice from a [updates] callback — the codegen entry.
  factory CastDevice([void Function(CastDeviceBuilder)? updates]) = _$CastDevice;

  /// Creates a discovered device.
  factory CastDevice.of({
    required String id,
    required String name,
    required String backendId,
    String? typeName,
    String? manufacturer,
    String? modelName,
    Map<String, String> serviceEndpoints = const <String, String>{},
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return CastDevice(
      (builder) => builder
        ..id = id
        ..name = name
        ..backendId = backendId
        ..typeName = typeName
        ..manufacturer = manufacturer
        ..modelName = modelName
        ..serviceEndpoints = serviceEndpoints
        ..attributes = attributes,
    );
  }

  CastDevice._();

  /// A discovered device is described by its three identities alone; the
  /// protocol detail a backend knows but the core does not is left empty.
  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(CastDeviceBuilder builder) => builder
    ..serviceEndpoints = const <String, String>{}
    ..attributes = const <String, Object?>{};

  /// Stable identity within one discovery session, normally the
  /// protocol's own UDN/device id.
  String get id;

  /// The friendly name the device advertises; what a picker shows.
  String get name;

  /// Which backend discovered this device (`dlna`, `cast`, ...).
  ///
  /// Carried on the device because a controller may hold several
  /// backends at once and commands must go back to the one that
  /// found the target.
  String get backendId;

  /// Protocol type name (a DLNA `urn:schemas-upnp-org:device:...`),
  /// when the device reports one.
  String? get typeName;

  /// Advertised manufacturer, when present.
  String? get manufacturer;

  /// Advertised model name, when present.
  String? get modelName;

  /// Control URLs or equivalent handles, keyed by service id.
  ///
  /// The map is opaque above the backend: keys and values mean
  /// whatever the discovering protocol says they mean, and the
  /// controller never reads them.
  Map<String, String> get serviceEndpoints;

  /// Extra device facts (icons, features); opaque to media_core.
  Map<String, Object?> get attributes;
}
