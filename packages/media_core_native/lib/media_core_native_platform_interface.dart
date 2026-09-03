import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'media_core_native_method_channel.dart';

abstract class MediaCoreNativePlatform extends PlatformInterface {
  /// Constructs a MediaCoreNativePlatform.
  MediaCoreNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static MediaCoreNativePlatform _instance = MethodChannelMediaCoreNative();

  /// The default instance of [MediaCoreNativePlatform] to use.
  ///
  /// Defaults to [MethodChannelMediaCoreNative].
  static MediaCoreNativePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MediaCoreNativePlatform] when
  /// they register themselves.
  static set instance(MediaCoreNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
