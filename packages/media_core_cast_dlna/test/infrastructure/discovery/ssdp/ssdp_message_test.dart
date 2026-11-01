import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

const String aliveTv = '''
NOTIFY * HTTP/1.1
HOST: 239.255.255.250:1900
CACHE-CONTROL: max-age=1800
LOCATION: http://192.168.1.40:9197/upnp/desc.xml
NT: urn:schemas-upnp-org:device:MediaRenderer:1
NTS: ssdp:alive
USN: uuid:TV-001::urn:schemas-upnp-org:device:MediaRenderer:1
''';

void main() {
  group('SsdpMessage', () {
    test('parses an alive announcement', () {
      final message = SsdpMessage.tryParse(aliveTv)!;

      expect(message.method, 'NOTIFY');
      expect(message.isAlive, isTrue);
      expect(message.isByebye, isFalse);
      expect(message.isUpdate, isFalse);
      expect(message.deviceId, 'uuid:TV-001');
      expect(message.location, 'http://192.168.1.40:9197/upnp/desc.xml');
      expect(message.notificationType, 'urn:schemas-upnp-org:device:MediaRenderer:1');
      expect(message.cacheLifetime, const Duration(seconds: 1800));
    });

    test('header names match case-insensitively', () {
      // Header NAMES are case-insensitive; the request line keeps its
      // spec-mandated uppercase method.
      final lowerNames = aliveTv
          .replaceFirst('HOST: ', 'host: ')
          .replaceFirst('CACHE-CONTROL: ', 'cache-control: ')
          .replaceFirst('LOCATION: ', 'location: ')
          .replaceFirst('NT: ', 'nt: ')
          .replaceFirst('NTS: ', 'nts: ')
          .replaceFirst('USN: ', 'usn: ');
      final message = SsdpMessage.tryParse(lowerNames)!;

      expect(message.method, 'NOTIFY');
      expect(message.deviceId, 'uuid:TV-001');
      expect(message.location, 'http://192.168.1.40:9197/upnp/desc.xml');
      expect(message.cacheLifetime, const Duration(seconds: 1800));
    });

    test('recognises byebye by NTS and by NT', () {
      expect(SsdpMessage.tryParse(aliveTv.replaceFirst('ssdp:alive', 'ssdp:byebye'))!.isByebye, isTrue);
      final ntStyle = aliveTv
          .replaceFirst('NTS: ssdp:alive', 'NTS: ssdp:byebye')
          .replaceFirst('NT: urn:schemas-upnp-org:device:MediaRenderer:1', 'NT: ssdp:byebye');
      expect(SsdpMessage.tryParse(ntStyle)!.isByebye, isTrue);
    });

    test('a search response is distinguished from a notification', () {
      const response = '''
HTTP/1.1 200 OK
CACHE-CONTROL: max-age=1800
ST: urn:schemas-upnp-org:device:MediaRenderer:1
USN: uuid:TV-002::urn:schemas-upnp-org:device:MediaRenderer:1
LOCATION: http://192.168.1.41:8090/desc.xml
''';

      final message = SsdpMessage.tryParse(response)!;

      expect(message.method, 'RESPONSE');
      expect(message.isSearchResponse, isTrue);
      expect(message.isAlive, isFalse);
      expect(message.notificationType, 'urn:schemas-upnp-org:device:MediaRenderer:1');
      expect(message.deviceId, 'uuid:TV-002');
    });

    test('an ssdp:update is neither alive nor byebye', () {
      final update = aliveTv.replaceFirst('ssdp:alive', 'ssdp:update');
      final message = SsdpMessage.tryParse(update)!;

      expect(message.isUpdate, isTrue);
      expect(message.isAlive, isFalse);
      expect(message.isByebye, isFalse);
    });

    test('missing cache-control defaults to a short lifetime', () {
      final noCache = aliveTv.replaceFirst('CACHE-CONTROL: max-age=1800\n', '');

      expect(SsdpMessage.tryParse(noCache)!.cacheLifetime, const Duration(seconds: 30));
    });

    test('garbage is skipped, not thrown', () {
      expect(SsdpMessage.tryParse(''), isNull);
      expect(SsdpMessage.tryParse('GET / HTTP/1.1\r\nHost: x\r\n'), isNull);
      expect(SsdpMessage.tryParse('NOTIFY * HTTP/1.1\r\n\r\n'), isNull);
    });
  });

  group('SsdpSearch', () {
    test('buildSearch carries the required MAN and target', () {
      final text = String.fromCharCodes(SsdpSearch.build(SsdpConstants.defaultSearchTargets.first));

      expect(text, contains('M-SEARCH * HTTP/1.1'));
      expect(text, contains('MAN: "ssdp:discover"'));
      expect(text, contains('HOST: ${SsdpConstants.multicastAddress}:${SsdpConstants.port}'));
      expect(text, contains('MX: 3'));
      expect(text, contains('ST: urn:schemas-upnp-org:device:MediaRenderer:1'));
    });

    test('the default targets cover both renderer generations', () {
      expect(SsdpConstants.defaultSearchTargets, contains('urn:schemas-upnp-org:device:MediaRenderer:1'));
      expect(SsdpConstants.defaultSearchTargets, contains('urn:schemas-upnp-org:device:MediaRenderer:2'));
    });
  });

  group('ServiceType', () {
    test('parses device and service URNs', () {
      final renderer = ServiceType.parse('urn:schemas-upnp-org:device:MediaRenderer:1');
      final transport = ServiceType.parse('urn:schemas-upnp-org:service:AVTransport:1');

      expect(renderer.isDevice, isTrue);
      expect(renderer.isMediaRenderer, isTrue);
      expect(renderer.version, 1);
      expect(transport.isService, isTrue);
      expect(transport.name, 'AVTransport');
      expect(transport.toString(), 'urn:schemas-upnp-org:service:AVTransport:1');
    });

    test('a padded or missing version does not drop the URN', () {
      expect(ServiceType.tryParse('urn:schemas-upnp-org:service:AVTransport')?.name, 'AVTransport');
      expect(ServiceType.tryParse('urn:schemas-upnp-org:device:MediaRenderer:x')?.version, isNull);
      expect(ServiceType.tryParse('http://not-a-urn'), isNull);
      expect(ServiceType.tryParse('urn:schemas-upnp-org:banana:Weird:1'), isNull);
    });

    test('equality is by fields', () {
      expect(
        ServiceType.parse('urn:schemas-upnp-org:device:MediaRenderer:1'),
        ServiceType.parse('urn:schemas-upnp-org:device:MediaRenderer:1'),
      );
    });
  });

  group('DurationCodec', () {
    test('clock strings format and round-trip, fractions tolerated', () {
      expect(DurationCodec.format(const Duration(hours: 2, minutes: 5, seconds: 9)), '02:05:09');
      expect(DurationCodec.format(const Duration(hours: 65)), '65:00:00');
      expect(DurationCodec.tryParse('00:01:30.500'), const Duration(minutes: 1, seconds: 30, milliseconds: 500));
      expect(DurationCodec.tryParse('01:02:03'), const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('non-clock position fields parse to null instead of throwing', () {
      expect(DurationCodec.tryParse('NOT_TRANSPRENT'), isNull);
      expect(DurationCodec.tryParse(''), isNull);
      expect(DurationCodec.tryParse(null), isNull);
    });
  });
}
