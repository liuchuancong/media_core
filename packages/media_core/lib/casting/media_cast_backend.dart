import 'dart:async';

import 'package:media_core/casting/cast_device.dart';
import 'package:media_core/casting/cast_media.dart';
import 'package:media_core/casting/cast_transport.dart';

/// Something happened on the cast side that the app must learn about.
///
/// Events, not return values: a device can leave the network while a
/// play command is in flight, and the only honest way to express that
/// is a stream that outlives any single call.
sealed class CastEvent {
  /// Creates an event.
  const CastEvent();
}

/// A device appeared (or re-announced itself) on the network.
final class DeviceFound extends CastEvent {
  /// Creates the event.
  const DeviceFound(this.device);

  /// The device.
  final CastDevice device;
}

/// A device went silent (BYEBYE) or its renewal lapsed.
final class DeviceLost extends CastEvent {
  /// Creates the event.
  const DeviceLost(this.deviceId);

  /// Identity of the device that left.
  final String deviceId;
}

/// The receiver's transport state changed.
final class TransportStateChanged extends CastEvent {
  /// Creates the event.
  const TransportStateChanged({required this.deviceId, required this.state});

  /// Device the state belongs to.
  final String deviceId;

  /// New state.
  final CastTransportState state;
}

/// The cast failed in a way the user must see.
final class CastFault extends CastEvent {
  /// Creates the event.
  const CastFault({required this.deviceId, required this.message, this.error});

  /// Device involved, when the fault is bound to one.
  final String? deviceId;

  /// Human-readable reason.
  final String message;

  /// Underlying error, when there was one.
  final Object? error;
}

/// A protocol implementation that can drive render devices.
///
/// The seam the casting feature is built on: media_core owns the
/// controller, device model and UI-facing state; a backend owns one
/// protocol's sockets and message encoding (SSDP + SOAP for DLNA, and
/// whatever else arrives later). Keeping the split here is what lets
/// an app cast without the core importing a single protocol byte, and
/// lets a protocol be added, or dropped, without the controller
/// noticing.
///
/// Implementations must:
///
/// - push [DeviceFound]/[DeviceLost] as discovery learns, and keep
///   alive renewals from silently extending a dead device's life;
/// - answer [position] even when the device has stopped responding,
///   with [CastPosition.unknown] rather than throwing, so a progress
///   ring can gray out instead of the UI crashing on a TV that just
///   left the Wi-Fi;
/// - throw [CastException] for command failures, never return an
///   error code an unwary caller might ignore.
abstract interface class MediaCastBackend {
  /// Stable backend identity (`dlna`, ...), matching
  /// [CastDevice.backendId].
  String get id;

  /// Stream of protocol events. Broadcast: a picker and a controller
  /// both watch the same discovery.
  Stream<CastEvent> get events;

  /// Starts discovery. Idempotent.
  Future<void> startDiscovery();

  /// Stops discovery and releases sockets. After this, [events] is
  /// closed and commands must fail with [CastException].
  ///
  /// Named apart from [stop] because the two end different things:
  /// this closes the backend's own resources, while [stop] tells one
  /// device to stop playing and leaves it castable again.
  Future<void> dispose();

  /// The devices currently considered present, in discovery order.
  List<CastDevice> get devices;

  /// Loads [media] on [device] without starting playback.
  Future<void> setMedia(CastDevice device, CastMedia media);

  /// Starts or resumes playback of the loaded media.
  Future<void> play(CastDevice device);

  /// Pauses playback.
  Future<void> pause(CastDevice device);

  /// Stops playback and releases the item.
  Future<void> stop(CastDevice device);

  /// Seeks to [position].
  Future<void> seek(CastDevice device, Duration position);

  /// Reads the receiver's playhead; see the [CastPosition.unknown]
  /// rule above before failing hard.
  Future<CastPosition> position(CastDevice device);

  /// Sets receiver volume, 0..100.
  Future<void> setVolume(CastDevice device, int percent);
}

/// A cast command failed.
final class CastException implements Exception {
  /// Creates an exception.
  const CastException(this.message, {this.deviceId, this.cause});

  /// Why the command failed.
  final String message;

  /// Device the failure belongs to, when bound to one.
  final String? deviceId;

  /// Underlying error.
  final Object? cause;

  @override
  String toString() => 'CastException: $message';
}
