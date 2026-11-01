import 'package:media_core_cast_dlna/src/domain/entities/dlna_device.dart';

/// UDN-keyed store of the devices discovery currently considers
/// present.
///
/// Insertion order is first-discovery order and survives updates: a
/// picker must not reshuffle its rows every time a TV renews its
/// announcement.
final class DlnaDeviceRegistry {
  final Map<String, DlnaDevice> _devices = <String, DlnaDevice>{};

  /// The devices, in discovery order.
  List<DlnaDevice> get devices => List<DlnaDevice>.unmodifiable(_devices.values);

  /// How many devices are currently held.
  int get length => _devices.length;

  /// Whether no device is held.
  bool get isEmpty => _devices.isEmpty;

  /// Whether any device is held.
  bool get isNotEmpty => _devices.isNotEmpty;

  /// The device with this UDN, when held.
  DlnaDevice? byUdn(String udn) => _devices[udn];

  /// Adds a device or replaces the record under the same UDN, keeping
  /// the original discovery position.
  void addOrUpdate(DlnaDevice device) {
    final existing = _devices[device.udn];
    if (existing == null) {
      _devices[device.udn] = device;
      return;
    }
    if (identical(existing, device)) {
      return;
    }
    // Dart maps have no insert-at-position, so a replacement rebuilds
    // the map with the new record at the old slot.
    final rebuilt = <String, DlnaDevice>{
      for (final entry in _devices.entries) entry.key: entry.key == device.udn ? device : entry.value,
    };
    _devices
      ..clear()
      ..addEntries(rebuilt.entries);
  }

  /// Removes a device; returns the record when it was held.
  DlnaDevice? remove(String udn) => _devices.remove(udn);

  /// Drops every device.
  void clear() => _devices.clear();
}
