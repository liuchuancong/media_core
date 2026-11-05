import 'dart:async';

import 'package:media_core_cast_dlna/src/application/playback/dlna_command_queue.dart';
import 'package:media_core_cast_dlna/src/application/playback/dlna_playback_controller.dart';
import 'package:media_core_cast_dlna/src/application/playback/dlna_playback_monitor.dart';
import 'package:media_core_cast_dlna/src/application/session/dlna_recovery_policy.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_device.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_media.dart';
import 'package:media_core_cast_dlna/src/domain/entities/dlna_playback_state.dart';
import 'package:media_core_cast_dlna/src/domain/enums/dlna_connection_state.dart';
import 'package:media_core_cast_dlna/src/domain/enums/dlna_media_type.dart';
import 'package:media_core_cast_dlna/src/domain/exceptions/dlna_exception.dart';
import 'package:media_core_cast_dlna/src/infrastructure/compatibility/device_compatibility.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/gena/gena_message_parser.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/gena/gena_subscriber.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/services/av_transport_service.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/services/rendering_control_service.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/didl_metadata.dart';
import 'package:media_core_cast_dlna/src/infrastructure/control/soap/soap_client.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/description_http_fetcher.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/device_description_parser.dart';
import 'package:media_core_cast_dlna/src/infrastructure/description/service_description_parser.dart';
import 'package:media_core_logging/media_core_logging.dart';

/// One cast session against one renderer (§8.3, §28).
///
/// A session is long-lived state: the device it plays on, the command
/// queue serializing every control action, the playback state the
/// monitor keeps fresh. Sessions and devices are separate things — one
/// device can host many sessions over its lifetime.
abstract interface class DlnaSession implements DlnaPlaybackController {
  /// The session identity (unique within this process).
  String get id;

  /// The renderer this session plays on. After a successful recovery
  /// this reflects the freshly resolved description (control URLs may
  /// have moved with the device's new address).
  DlnaDevice get device;

  /// Where the session's connection stands.
  DlnaConnectionState get connectionState;

  /// Connection changes, after the fact.
  Stream<DlnaConnectionState> get connectionStateStream;

  /// The latest merged playback state.
  DlnaPlaybackState get playbackState;

  /// Playback state updates: monitor polls, command follow-ups and
  /// GENA pushes all land here.
  Stream<DlnaPlaybackState> get playbackStateStream;

  /// The attached GENA subscriber, when eventing is wired up; without
  /// one the session runs entirely on its polling fallback.
  GenaSubscriber? get gena;

  /// Validates the device and opens the session. Idempotent while
  /// connected.
  Future<void> connect();

  /// Sets the receiver's Master volume (0..100). Requires a device
  /// RenderingControl service (§12.4).
  Future<void> setVolume(int percent);

  /// Mutes or unmutes the receiver's Master channel. Requires a device
  /// RenderingControl service.
  Future<void> setMute({required bool muted});

  /// Ends the session: pending commands are dropped, polling stops,
  /// the device keeps whatever it is doing.
  Future<void> disconnect();

  /// Disconnects and releases every resource this session holds.
  Future<void> dispose();
}

/// The [DlnaSession] implementation: commands through a serial queue,
/// state merged from command follow-ups, monitor polls and GENA pushes,
/// seek validated against what the device last reported, and a bounded
/// recovery loop that re-resolves the device when the network drops it
/// (§20.4).
final class DlnaSessionController implements DlnaSession {
  /// Creates a controller for [device].
  ///
  /// [client] is shared infrastructure and not owned by the session.
  /// [fetchScpd], when given, loads the AVTransport SCPD during
  /// [connect] so actions the device does not declare are refused
  /// locally; a failed load degrades to no local check. [genaFactory],
  /// when given, re-builds the eventing subscription — initially and
  /// after every recovery. [now] is injectable for deterministic tests.
  DlnaSessionController({
    required DlnaDevice device,
    required SoapClient client,
    DlnaPlaybackMonitorOptions? monitorOptions,
    this.fetchScpd,
    this.recoveryPolicy = const DlnaRecoveryPolicy(),
    DeviceCompatibilityProfile profile = const DeviceCompatibilityProfile.standard(),
    Future<GenaSubscriber> Function(DlnaDevice device)? genaFactory,
    DateTime Function()? now,
  }) : _device = device,
       _client = client,
       _monitorOptions = monitorOptions ?? const DlnaPlaybackMonitorOptions(),
       _profile = profile,
       _genaFactory = genaFactory,
       _now = now ?? DateTime.now {
    _state = DlnaPlaybackState(updatedAt: _now());
  }

  static int _counter = 0;

  /// This session's identity, fixed at construction. A getter that
  /// incremented the counter on every read would hand a different id to
  /// every log line and every consumer that compared ids.
  final String _id = 'dlna-session-${_counter++}';

  DlnaDevice _device;

  /// The renderer this session plays on.
  @override
  DlnaDevice get device => _device;

  /// The SCPD loader armed during [connect], when a host supplied one.
  final DescriptionFetcher? fetchScpd;

  /// What happens when the network drops the device (§20.4).
  final DlnaRecoveryPolicy recoveryPolicy;

  /// The vendor-quirk profile this session runs under (§9).
  final DeviceCompatibilityProfile _profile;

  final SoapClient _client;
  final DlnaPlaybackMonitorOptions _monitorOptions;
  final Future<GenaSubscriber> Function(DlnaDevice device)? _genaFactory;
  final DateTime Function() _now;

  final DlnaCommandQueue _queue = DlnaCommandQueue();
  late final DlnaPlaybackMonitor _monitor = DlnaPlaybackMonitor(onTick: _onMonitorTick, options: _monitorOptions);

  final StreamController<DlnaPlaybackState> _playback = StreamController<DlnaPlaybackState>.broadcast();
  final StreamController<DlnaConnectionState> _connection = StreamController<DlnaConnectionState>.broadcast();

  GenaSubscriber? _gena;

  Set<String>? _supportedActions;
  Set<String>? _renderingActions;
  late DlnaPlaybackState _state;
  DlnaConnectionState _connectionState = DlnaConnectionState.disconnected;
  bool _disposed = false;
  bool _recovering = false;

  /// The transport facade; stateless, so it is rebuilt as its inputs
  /// (the SCPD-derived action set, the resolved device) mature.
  AvTransportService get _transport => AvTransportService(
    client: _client,
    service: device.avTransport!,
    supportedActions: _supportedActions,
    profile: _profile,
  );

  /// The volume facade, when the device declares RenderingControl.
  RenderingControlService? get _rendering => device.renderingControl == null
      ? null
      : RenderingControlService(
          client: _client,
          service: device.renderingControl!,
          supportedActions: _renderingActions,
        );

  @override
  String get id => _id;

  @override
  DlnaConnectionState get connectionState => _connectionState;

  @override
  Stream<DlnaConnectionState> get connectionStateStream => _connection.stream;

  @override
  DlnaPlaybackState get playbackState => _state;

  @override
  Stream<DlnaPlaybackState> get playbackStateStream => _playback.stream;

  void _setConnection(DlnaConnectionState state) {
    _connectionState = state;
    _connection.add(state);
  }

  void _setPlayback(DlnaPlaybackState state) {
    // An in-flight poll or GENA delivery may land after dispose closed
    // the controllers; dropping the update beats a StateError.
    if (_disposed) {
      return;
    }
    _state = state;
    _playback.add(state);
    _monitor.updateTransportState(state.transportState);
  }

  @override
  Future<void> connect() async {
    if (_disposed) {
      throw const DlnaSessionException('session is disposed');
    }
    if (_connectionState == DlnaConnectionState.connected) {
      return;
    }
    if (device.avTransport == null) {
      _setConnection(DlnaConnectionState.failed);
      throw const DlnaSessionException('device exposes no AVTransport service');
    }
    _setConnection(DlnaConnectionState.connecting);
    try {
      await _loadSupportedActions();
      _monitor.start();
      await _armGena();
      _setConnection(DlnaConnectionState.connected);
      MediaCoreLog.info(
        LogCategory.session,
        'session connected',
        fields: <String, Object?>{'device': device.udn, 'session': id},
      );
    } on Object {
      _setConnection(DlnaConnectionState.failed);
      rethrow;
    }
  }

  /// The attached GENA subscriber, when eventing is wired up; without
  /// one the session runs entirely on its polling fallback.
  @override
  GenaSubscriber? get gena => _gena;

  set gena(GenaSubscriber subscriber) {
    _gena = subscriber;
  }

  /// Subscribes the attached subscriber; a failure here only means the
  /// polling fallback carries the session (§14.7), never a connect
  /// failure.
  Future<void> _armGena() async {
    var subscriber = _gena;
    if (subscriber == null) {
      final factory = _genaFactory;
      if (factory == null || device.avTransport?.eventSubUrl == null) {
        return;
      }
      try {
        subscriber = await factory(device);
      } on Object catch (error) {
        // Eventing unavailable; the monitor keeps state flowing.
        MediaCoreLog.warning(
          LogCategory.session,
          'eventing subscriber unavailable',
          error: error,
          fields: <String, Object?>{'device': device.udn},
        );
        return;
      }
      _gena = subscriber;
    }
    try {
      await subscriber.subscribe();
    } on Object catch (error) {
      // Eventing unavailable; the monitor keeps state flowing.
      MediaCoreLog.warning(
        LogCategory.session,
        'GENA subscribe failed; polling carries on',
        error: error,
        fields: <String, Object?>{'device': device.udn},
      );
    }
  }

  /// Merges one GENA event into the playback snapshot (§19.1: pushed
  /// state wins over the next poll). Absent variables leave their
  /// fields untouched.
  void handleGenaNotification(GenaNotification notification) {
    if (_disposed || _connectionState != DlnaConnectionState.connected) {
      return;
    }
    final variables = notification.variables;
    final rawVolume = variables['Volume'];
    final rawMute = variables['Mute'];
    _setPlayback(
      _state.copyWith(
        transportState: variables.transportState,
        position: variables.position,
        duration: variables.duration,
        currentUri: variables.trackUri,
        volume: rawVolume == null ? null : int.tryParse(rawVolume.trim())?.clamp(0, 100),
        isMuted: rawMute == null
            ? null
            : switch (rawMute.trim().toLowerCase()) {
                '1' || 'true' || 'yes' => true,
                '0' || 'false' || 'no' => false,
                _ => null,
              },
        updatedAt: _now(),
      ),
    );
  }

  /// Loads the AVTransport (and RenderingControl) SCPDs and arms the
  /// local capability checks.
  ///
  /// A device whose SCPD cannot be read is not refused — it just loses
  /// the local pre-flight and fails at the wire like every other
  /// non-declaring device. The two documents are independent reads, so
  /// they load concurrently instead of doubling the connect path's
  /// round-trip count.
  Future<void> _loadSupportedActions() async {
    final fetch = fetchScpd;
    if (fetch == null) {
      return;
    }
    await Future.wait<void>(<Future<void>>[_loadAvTransportActions(fetch), _loadRenderingControlActions(fetch)]);
  }

  Future<void> _loadAvTransportActions(DescriptionFetcher fetch) async {
    final avScpdUrl = device.avTransport?.scpdUrl;
    if (avScpdUrl == null) {
      return;
    }
    try {
      final description = ServiceDescriptionParser.parse(await fetch(avScpdUrl.toString()));
      _supportedActions = description.actions.keys.toSet();
    } on Object catch (error) {
      MediaCoreLog.warning(
        LogCategory.session,
        'service description fetch failed; actions unrestricted',
        error: error,
        fields: <String, Object?>{'device': device.udn},
      );
      _supportedActions = null;
    }
  }

  Future<void> _loadRenderingControlActions(DescriptionFetcher fetch) async {
    final rcScpdUrl = device.renderingControl?.scpdUrl;
    if (rcScpdUrl == null) {
      return;
    }
    try {
      final description = ServiceDescriptionParser.parse(await fetch(rcScpdUrl.toString()));
      _renderingActions = description.actions.keys.toSet();
    } on Object catch (error) {
      MediaCoreLog.warning(
        LogCategory.session,
        'service description fetch failed; actions unrestricted',
        error: error,
        fields: <String, Object?>{'device': device.udn},
      );
      _renderingActions = null;
    }
  }

  @override
  Future<void> setMedia(DlnaMedia media) async {
    return await _submit(() async {
      final resource = media.resources.isEmpty ? null : media.resources.first;
      final url = resource?.uri.toString() ?? media.sourceUri.toString();
      final mimeType = resource?.mimeType ?? media.mimeType ?? DidlMetadata.mimeTypeForUrl(url);
      // §9: a minority of firmwares reject DIDL outright — the profile
      // decides whether the payload is sent at all.
      final metadata = _profile.omitDidl
          ? ''
          : DidlMetadata.build(
              title: media.title,
              url: media.sourceUri.toString(),
              mimeType: mimeType,
              mediaType: media.mediaType == DlnaMediaType.unknown
                  ? DlnaMediaType.fromMimeType(mimeType)
                  : media.mediaType,
              resourceUrl: url,
            );
      await _transport.setUri(url, metadata);
      await _refreshTransport();
      _setPlayback(
        _state.copyWith(position: Duration.zero, currentUri: url, currentTitle: media.title, updatedAt: _now()),
      );
    });
  }

  @override
  Future<void> play() async {
    return await _submit(() async {
      await _transport.play();
      await _refreshTransport();
      _setPlayback(_state.copyWith(updatedAt: _now()));
    });
  }

  @override
  Future<void> pause() async {
    return await _submit(() async {
      await _transport.pause();
      await _refreshTransport();
      _setPlayback(_state.copyWith(updatedAt: _now()));
    });
  }

  @override
  Future<void> stop() async {
    // §18.5: a stop cancels the queued backlog first, so a queued play
    // cannot fire after the user asked for silence. The stop itself
    // still runs through the queue, behind whatever command is already
    // on the wire.
    _queue.cancelPending();
    return await _submit(() async {
      await _transport.stop();
      await _refreshTransport();
      _setPlayback(_state.copyWith(updatedAt: _now()));
    });
  }

  @override
  Future<void> seek(Duration position) async {
    if (position.isNegative) {
      throw ArgumentError.value(position, 'position', 'seek target must not be negative');
    }
    final duration = _state.duration;
    if (duration != null && position > duration) {
      throw ArgumentError.value(position, 'position', 'seek target is beyond the known duration $duration');
    }
    return await _submit(() async {
      await _transport.seek(position);
      await _refreshTransport();
      _setPlayback(_state.copyWith(position: position, updatedAt: _now()));
    });
  }

  @override
  Future<void> setVolume(int percent) async {
    final rendering = _rendering;
    if (rendering == null) {
      throw const DlnaSessionException('device exposes no RenderingControl service');
    }
    return await _submit(() async {
      final applied = await rendering.setVolume(percent);
      _setPlayback(_state.copyWith(volume: applied, updatedAt: _now()));
    });
  }

  @override
  Future<void> setMute({required bool muted}) async {
    final rendering = _rendering;
    if (rendering == null) {
      throw const DlnaSessionException('device exposes no RenderingControl service');
    }
    return await _submit(() async {
      await rendering.setMute(muted: muted);
      _setPlayback(_state.copyWith(isMuted: muted, updatedAt: _now()));
    });
  }

  /// Reads the device's volume and mute into the snapshot without
  /// touching the command queue.
  ///
  /// The two reads are independent, so they go out together. An answer
  /// whose probe started before a newer write landed on the snapshot is
  /// dropped: a volume the user set while the probe was in flight must
  /// not be overwritten by the stale value the device was still
  /// holding.
  Future<void> readVolumeState() async {
    final rendering = _rendering;
    if (rendering == null) {
      return;
    }
    final observedAt = _now();
    try {
      // Future.wait with the default eagerError waits for both futures
      // before surfacing the first error, so a failing probe cannot
      // strand the sibling's error unhandled.
      final answers = await Future.wait<Object?>(<Future<Object?>>[rendering.getVolume(), rendering.isMuted()]);
      if (_disposed || observedAt.isBefore(_state.updatedAt)) {
        return;
      }
      _setPlayback(
        _state.copyWith(volume: answers[0]! as int, isMuted: answers[1]! as bool, updatedAt: _now()),
      );
    } on DlnaException catch (error) {
      // A volume probe that fails leaves the snapshot alone.
      MediaCoreLog.debug(
        LogCategory.session,
        'volume probe failed',
        error: error,
        fields: <String, Object?>{'device': device.udn},
      );
    }
  }

  @override
  Future<DlnaPlaybackState> getPlaybackState() async {
    _assertUsable();
    await _readState();
    await readVolumeState();
    return _state;
  }

  @override
  Future<Duration?> getPosition() => getPlaybackState().then((state) => state.position);

  @override
  Future<Duration?> getDuration() => getPlaybackState().then((state) => state.duration);

  @override
  Future<void> disconnect() async {
    if (_connectionState == DlnaConnectionState.disconnected) {
      return;
    }
    _setConnection(DlnaConnectionState.disconnecting);
    _queue.cancelPending();
    _monitor.stop();
    _setConnection(DlnaConnectionState.disconnected);
    MediaCoreLog.info(
      LogCategory.session,
      'session disconnected',
      fields: <String, Object?>{'device': device.udn, 'session': id},
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await disconnect();
    await _gena?.dispose();
    _monitor.dispose();
    await _queue.dispose();
    await _playback.close();
    await _connection.close();
  }

  void _assertUsable() {
    if (_disposed) {
      throw const DlnaSessionException('session is disposed');
    }
    if (_connectionState != DlnaConnectionState.connected) {
      throw const DlnaSessionException('session is not connected');
    }
  }

  /// The single entry point for session commands: validates usability,
  /// serializes through the queue, and arms recovery when the network
  /// world broke (§20.3) — device-refusal errors do not recover, the
  /// TV answered.
  Future<T> _submit<T>(Future<T> Function() action) async {
    _assertUsable();
    try {
      return await _queue.submit(action);
    } on DlnaNetworkException catch (error) {
      MediaCoreLog.warning(
        LogCategory.session,
        'command failed on the network',
        error: error,
        fields: <String, Object?>{'device': device.udn},
      );
      _scheduleRecovery();
      rethrow;
    }
  }

  /// Starts the bounded recovery loop once; concurrent triggers are
  /// absorbed (§20.4).
  void _scheduleRecovery() {
    if (!recoveryPolicy.enabled || _recovering || _disposed || _connectionState != DlnaConnectionState.connected) {
      return;
    }
    _recovering = true;
    MediaCoreLog.warning(
      LogCategory.session,
      'device unreachable; recovery started',
      fields: <String, Object?>{'device': device.udn},
    );
    _setConnection(DlnaConnectionState.reconnecting);
    _monitor.stop();
    unawaited(_recoverLoop());
  }

  /// §20.4: re-resolve the device description (its address may have
  /// moved), rebuild services and eventing, probe, and only then call
  /// the session connected. What is playing is *not* re-pushed without
  /// confirmation — a recovery that finds the TV still playing must not
  /// restart the film.
  Future<void> _recoverLoop() async {
    for (var attempt = 1; attempt <= recoveryPolicy.maxAttempts; attempt++) {
      if (attempt > 1 && recoveryPolicy.retryDelay > Duration.zero) {
        await Future<void>.delayed(recoveryPolicy.retryDelay);
      }
      // A disconnect (or a dispose) that landed while this loop was
      // between attempts must not be overridden by a later attempt
      // succeeding: the user asked for silence, not a resurrected
      // session. Only the state [DlnaConnectionState.reconnecting]
      // means recovery still owns the connection.
      if (_disposed || _connectionState != DlnaConnectionState.reconnecting) {
        _recovering = false;
        return;
      }
      try {
        await _resolveDevice();
        _supportedActions = null;
        _renderingActions = null;
        await _loadSupportedActions();
        await _rearmGena();
        // Reachability probe: the first command after recovery must not
        // be the one discovering the device is still gone.
        await _transport.getTransportInfo();
        if (_disposed || _connectionState != DlnaConnectionState.reconnecting) {
          _recovering = false;
          return;
        }
        _recovering = false;
        _setPlayback(_state.copyWith(updatedAt: _now()));
        _monitor.start();
        _setConnection(DlnaConnectionState.connected);
        MediaCoreLog.info(
          LogCategory.session,
          'session recovered',
          fields: <String, Object?>{'device': device.udn, 'attempt': attempt},
        );
        return;
      } on Object catch (error) {
        // The next attempt (or the failure path below) handles it.
        MediaCoreLog.debug(
          LogCategory.session,
          'recovery attempt failed; retrying',
          error: error,
          fields: <String, Object?>{'device': device.udn},
        );
      }
    }
    if (_disposed || _connectionState != DlnaConnectionState.reconnecting) {
      _recovering = false;
      return;
    }
    _recovering = false;
    MediaCoreLog.error(
      LogCategory.session,
      'session recovery exhausted',
      fields: <String, Object?>{'device': device.udn, 'attempts': recoveryPolicy.maxAttempts},
    );
    _setConnection(DlnaConnectionState.failed);
  }

  /// Re-fetches the description document and verifies it still belongs
  /// to this session's UDN before adopting its endpoints.
  Future<void> _resolveDevice() async {
    final fetch = fetchScpd;
    if (fetch == null) {
      return;
    }
    final xml = await fetch(device.location.toString());
    final parsed = DeviceDescriptionParser.parse(xml, location: device.location, maxAge: device.maxAge);
    if (parsed.udn != _device.udn) {
      throw DlnaDeviceDescriptionException(
        'device at ${device.location} now answers as ${parsed.udn}, expected ${_device.udn}',
      );
    }
    _device = parsed;
  }

  /// Tears down the old subscription and builds a fresh one against
  /// the recovered device via the manager's factory.
  Future<void> _rearmGena() async {
    await _gena?.dispose();
    _gena = null;
    final factory = _genaFactory;
    if (factory == null || device.avTransport?.eventSubUrl == null) {
      return;
    }
    try {
      final subscriber = await factory(device);
      _gena = subscriber;
      await subscriber.subscribe();
    } on Object {
      // §14.7: eventing lost; the polling fallback carries on.
      MediaCoreLog.warning(
        LogCategory.session,
        'eventing lost after recovery; polling fallback',
        fields: <String, Object?>{'device': device.udn},
      );
    }
  }

  /// One device read: transport state plus position, merged into the
  /// snapshot. The two reads are independent and go out together, so a
  /// poll costs one round-trip span instead of two. A silent device
  /// leaves the snapshot untouched except for its freshness — one
  /// missed poll must not flash a UI to "unknown" — and an answer whose
  /// read started before a newer write landed (a seek's follow-up, a
  /// GENA push) is dropped rather than rolling the playhead back.
  Future<void> _readState() async {
    final observedAt = _now();
    try {
      final answers = await Future.wait<Object?>(<Future<Object?>>[
        _transport.getTransportInfo(),
        _transport.getPositionInfo(),
      ]);
      final transport = answers[0]! as AvTransportState;
      final position = answers[1]! as AvTransportPosition;
      if (_disposed || observedAt.isBefore(_state.updatedAt)) {
        return;
      }
      _setPlayback(
        _state.copyWith(
          transportState: transport.transportState,
          position: position.position,
          duration: position.duration,
          currentUri: position.trackUri ?? _state.currentUri,
          updatedAt: _now(),
        ),
      );
    } on DlnaException catch (error) {
      MediaCoreLog.debug(
        LogCategory.session,
        'device state read failed',
        error: error,
        fields: <String, Object?>{'device': device.udn},
      );
      if (_disposed) {
        return;
      }
      _setPlayback(_state.copyWith(updatedAt: _now()));
    }
  }

  /// Command follow-up: verify what the device actually did (§18.3 —
  /// an accepted action is not a playing renderer).
  Future<void> _refreshTransport() async {
    try {
      final transport = await _transport.getTransportInfo();
      _setPlayback(_state.copyWith(transportState: transport.transportState, updatedAt: _now()));
    } on DlnaException catch (error) {
      // The command went out; the state stays as reported before.
      MediaCoreLog.debug(
        LogCategory.session,
        'device state read failed',
        error: error,
        fields: <String, Object?>{'device': device.udn},
      );
    }
  }

  /// The monitor's timer fires regardless of whether the previous read
  /// finished (its `onTick` is synchronous), so without this guard a
  /// device slower than the cadence would stack reads forever — each
  /// paying a SOAP round trip and each able to land out of order.
  bool _readInFlight = false;

  void _onMonitorTick() {
    if (_readInFlight) {
      return;
    }
    _readInFlight = true;
    unawaited(_readState().whenComplete(() => _readInFlight = false));
  }
}
