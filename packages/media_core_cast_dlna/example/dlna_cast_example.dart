// A minimal end-to-end tour of media_core_cast_dlna: discover renderers
// on the LAN, cast a local file through the built-in media server, and
// drive playback. This file is the pub.dev example; it is compiled by
// `dart analyze` but requires real devices (or the injectable seams
// shown in the package tests) to actually run.

import 'dart:async';

import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

Future<void> main() async {
  // 1. Create the facade. GENA eventing and the compatibility registry
  //    are on by default; media server and transports are created
  //    lazily and closed by dispose().
  final dlna = DlnaClient();

  // 2. Discover renderers. `devices` fires after every mutation with
  //    the full snapshot; a device only appears once its description
  //    resolved and it declared an AVTransport service.
  await dlna.startDiscovery();
  final devicesSub = dlna.devices.listen((devices) {
    for (final device in devices) {
      // A real app renders this into a picker; the example prints.
      // ignore: avoid_print, host demo output
      print('renderer: ${device.friendlyName} (${device.udn})');
    }
  });

  // 3. Wait for the first device (a real app surfaces this as a picker).
  final tv = await dlna.devices
      .map((devices) => devices.isEmpty ? null : devices.first)
      .firstWhere((device) => device != null);
  if (tv == null) {
    return;
  }

  // 4. Prepare media: local files are rewritten through the media
  //    server (the path never reaches the TV), and the device's own
  //    GetProtocolInfo answer vetoes formats it cannot play.
  final media = await dlna.prepareMedia(device: tv, title: '第四集', url: 'D:/Movies/第四集.mp4');

  // 5. Connect a session and drive playback. Commands serialize through
  //    the session's queue; pushed GENA state updates the snapshot.
  final session = await dlna.connect(tv);
  session.playbackStateStream.listen((state) {
    // ignore: avoid_print, host demo output
    print('${state.transportState} ${state.position}/${state.duration}');
  });

  await session.setMedia(media);
  await session.play();
  await session.seek(const Duration(minutes: 3));
  await session.setVolume(40);

  // 6. Tune down: stop cancels queued commands; disconnect releases the
  //    session and unregisters its media; dispose closes everything.
  await session.stop();
  await devicesSub.cancel();
  await dlna.disconnect(session);
  await dlna.dispose();
}
