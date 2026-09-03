import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_core_native_platform_interface.dart';

/// An implementation of [MediaCoreNativePlatform] that uses method channels.
class MethodChannelMediaCoreNative extends MediaCoreNativePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('media_core_native');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
