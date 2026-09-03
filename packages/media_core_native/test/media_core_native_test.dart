import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_native/media_core_native.dart';
import 'package:media_core_native/media_core_native_platform_interface.dart';
import 'package:media_core_native/media_core_native_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediaCoreNativePlatform
    with MockPlatformInterfaceMixin
    implements MediaCoreNativePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MediaCoreNativePlatform initialPlatform = MediaCoreNativePlatform.instance;

  test('$MethodChannelMediaCoreNative is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMediaCoreNative>());
  });

  test('getPlatformVersion', () async {
    MediaCoreNative mediaCoreNativePlugin = MediaCoreNative();
    MockMediaCoreNativePlatform fakePlatform = MockMediaCoreNativePlatform();
    MediaCoreNativePlatform.instance = fakePlatform;

    expect(await mediaCoreNativePlugin.getPlatformVersion(), '42');
  });
}
