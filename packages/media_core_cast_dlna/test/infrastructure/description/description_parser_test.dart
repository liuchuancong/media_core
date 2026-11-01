import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart';

const String description = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>Salon TV</friendlyName>
    <manufacturer>Anyka</manufacturer>
    <modelName>K7</modelName>
    <modelNumber>2024</modelNumber>
    <UDN>uuid:TV-001</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
        <SCPDURL>/scpd/AVT.xml</SCPDURL>
        <controlURL>/upnp/ctrl/AVTransport</controlURL>
        <eventSubURL>/upnp/event/AVTransport</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>upnp/ctrl/RC</controlURL>
      </service>
    </serviceList>
  </device>
</root>
''';

final Uri location = Uri.parse('http://192.168.1.40:9197/upnp/desc.xml');

void main() {
  group('DeviceDescriptionParser', () {
    test('reads identity and resolves both relative URL styles', () {
      final device = DeviceDescriptionParser.parse(description, location: location);

      expect(device.udn, 'uuid:TV-001');
      expect(device.friendlyName, 'Salon TV');
      expect(device.manufacturer, 'Anyka');
      expect(device.modelName, 'K7');
      expect(device.modelNumber, '2024');
      expect(device.deviceType, 'urn:schemas-upnp-org:device:MediaRenderer:1');
      expect(device.isMediaRenderer, isTrue);
      expect(device.avTransport!.controlUrl, Uri.parse('http://192.168.1.40:9197/upnp/ctrl/AVTransport'));
      // A bare relative control URL anchors at the host root, not at
      // the description document's path.
      expect(device.renderingControl!.controlUrl, Uri.parse('http://192.168.1.40:9197/upnp/ctrl/RC'));
      expect(device.avTransport!.serviceId, 'urn:upnp-org:serviceId:AVTransport');
      expect(device.avTransport!.scpdUrl, Uri.parse('http://192.168.1.40:9197/scpd/AVT.xml'));
      expect(device.avTransport!.eventSubUrl, Uri.parse('http://192.168.1.40:9197/upnp/event/AVTransport'));
    });

    test('absolute control URLs pass through untouched', () {
      final absolute = description.replaceAll('/upnp/ctrl/AVTransport', 'http://10.0.0.5:8080/av');

      final device = DeviceDescriptionParser.parse(absolute, location: location);

      expect(device.avTransport!.controlUrl, Uri.parse('http://10.0.0.5:8080/av'));
    });

    test('URLBase overrides the location origin', () {
      final withBase = description.replaceFirst(
        '<specVersion>',
        '<URLBase>http://10.1.2.3:49152/</URLBase><specVersion>',
      );

      final device = DeviceDescriptionParser.parse(withBase, location: location);

      expect(device.avTransport!.controlUrl, Uri.parse('http://10.1.2.3:49152/upnp/ctrl/AVTransport'));
    });

    test('an embedded device contributes its services', () {
      const embedded = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaServer:1</deviceType>
    <friendlyName>Hub</friendlyName>
    <UDN>uuid:HUB-001</UDN>
    <deviceList>
      <device>
        <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
        <friendlyName>Hub Renderer</friendlyName>
        <UDN>uuid:HUB-001</UDN>
        <serviceList>
          <service>
            <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
            <controlURL>/hub/av</controlURL>
          </service>
        </serviceList>
      </device>
    </deviceList>
  </device>
</root>
''';

      final device = DeviceDescriptionParser.parse(embedded, location: location);

      expect(device.friendlyName, 'Hub');
      expect(device.avTransport!.controlUrl, Uri.parse('http://192.168.1.40:9197/hub/av'));
    });

    test('a missing friendlyName falls back to the UDN', () {
      final anonymous = description.replaceFirst('<friendlyName>Salon TV</friendlyName>', '');

      final device = DeviceDescriptionParser.parse(anonymous, location: location);

      expect(device.friendlyName, 'uuid:TV-001');
    });

    test('a device without AVTransport parses; the capability gate decides', () {
      final noTransport = description.replaceAll(RegExp('<service>.*?AVTransport.*?</service>', dotAll: true), '');

      final device = DeviceDescriptionParser.parse(noTransport, location: location);

      expect(device.avTransport, isNull);
      expect(device.renderingControl, isNotNull);
    });

    test('a missing UDN is refused', () {
      final noUdn = description.replaceAll('<UDN>uuid:TV-001</UDN>', '');

      expect(
        () => DeviceDescriptionParser.parse(noUdn, location: location),
        throwsA(isA<DlnaDeviceDescriptionException>()),
      );
    });

    test('malformed XML is refused', () {
      expect(
        () => DeviceDescriptionParser.parse('<root><device>', location: location),
        throwsA(isA<DlnaDeviceDescriptionException>()),
      );
    });
  });

  group('ServiceDescriptionParser', () {
    const scpd = '''
<?xml version="1.0"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <actionList>
    <action>
      <name>Play</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Speed</name>
          <direction>in</direction>
          <relatedStateVariable>TransportPlaySpeed</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>GetPositionInfo</name>
    </action>
  </actionList>
  <serviceStateTable>
    <stateVariable sendEvents="yes">
      <name>TransportState</name>
      <dataType>string</dataType>
      <allowedValueList>
        <allowedValue>STOPPED</allowedValue>
        <allowedValue>PLAYING</allowedValue>
        <allowedValue>PAUSED_PLAYBACK</allowedValue>
      </allowedValueList>
    </stateVariable>
  </serviceStateTable>
</scpd>
''';

    test('reads actions, arguments and state variables', () {
      final parsed = ServiceDescriptionParser.parse(scpd);

      expect(parsed.supportsAction('Play'), isTrue);
      expect(parsed.supportsAction('Seek'), isFalse);
      expect(parsed.actions['Play']!.arguments.map((a) => a.name), <String>['InstanceID', 'Speed']);
      expect(parsed.actions['Play']!.arguments.first.direction, 'in');
      expect(parsed.stateVariables['TransportState']!.allowedValues, contains('PLAYING'));
      expect(parsed.stateVariables['TransportState']!.dataType, 'string');
    });

    test('malformed XML is refused', () {
      expect(() => ServiceDescriptionParser.parse('<scpd'), throwsA(isA<DlnaServiceDescriptionException>()));
    });
  });
}
