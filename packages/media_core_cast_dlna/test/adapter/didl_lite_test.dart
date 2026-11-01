import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

void main() {
  group('DidlLite.build', () {
    test('escapes markup in title and url', () {
      final didl = DidlLite.build(
        const CastMedia(url: 'https://cdn.example.com/a&b<b>.mp4', title: 'Tom & Jerry <The Movie>'),
      );

      expect(didl, contains('&amp;b&lt;b&gt;'));
      expect(didl, contains('Tom &amp; Jerry &lt;The Movie&gt;'));
      // No raw ampersand or angle bracket may survive inside the
      // title — that is markup injection into the device's XML.
      expect(didl, isNot(contains('<dc:title>Tom & Jerry')));
    });

    test('mime comes from the declaration, else from the extension', () {
      final declared = DidlLite.build(const CastMedia(url: 'https://x/y', title: 't', mimeType: 'video/x-matroska'));
      final guessed = DidlLite.build(const CastMedia(url: 'https://x/y.mkv', title: 't'));

      expect(declared, contains('http-get:video/x-matroska:'));
      expect(guessed, contains('http-get:video/x-matroska:'));
    });

    test('an unknown mime still emits a usable res line', () {
      final didl = DidlLite.build(const CastMedia(url: 'https://x/stream', title: 't'));

      // MIME `*` with an empty profile: legal, and devices fall back
      // to sniffing. A fabricated profile hint would be worse than no
      // hint at all.
      expect(didl, contains('protocolInfo="http-get:*:"'));
      expect(didl, contains('mimeType="*"'));
    });

    test('creator and artwork reach the document', () {
      final didl = DidlLite.build(
        CastMedia(
          url: 'https://x/a.mp3',
          title: 'Song',
          creator: 'Band',
          artworkUrl: Uri.parse('https://x/cover.jpg'),
          objectClass: 'audio.item',
        ),
      );

      expect(didl, contains('<dc:creator>Band</dc:creator>'));
      expect(didl, contains('<upnp:albumArtURI>https://x/cover.jpg</upnp:albumArtURI>'));
      expect(didl, contains('<upnp:class>audio.item</upnp:class>'));
    });
  });

  group('DlnaDeviceRegistry', () {
    test('replacement keeps the original discovery position', () {
      final registry = DlnaDeviceRegistry();
      final first = _device('uuid:A', 'First');
      final second = _device('uuid:B', 'Second');
      registry
        ..addOrUpdate(first)
        ..addOrUpdate(second)
        ..addOrUpdate(_device('uuid:A', 'First-renamed'));

      expect(registry.devices.map((device) => device.udn), <String>['uuid:A', 'uuid:B']);
      expect(registry.byUdn('uuid:A')!.friendlyName, 'First-renamed');
      expect(registry.remove('uuid:B')!.friendlyName, 'Second');
      expect(registry.length, 1);
      registry.clear();
      expect(registry.isEmpty, isTrue);
    });
  });
}

DlnaDevice _device(String udn, String name) {
  return DlnaDevice(
    udn: udn,
    friendlyName: name,
    deviceType: 'urn:schemas-upnp-org:device:MediaRenderer:1',
    location: Uri.parse('http://tv/desc.xml'),
    services: const <DlnaService>[],
    discoveredAt: DateTime(2026),
    lastSeenAt: DateTime(2026),
  );
}
