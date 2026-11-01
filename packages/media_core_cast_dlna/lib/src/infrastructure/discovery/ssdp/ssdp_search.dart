import 'dart:convert' show utf8;

import 'package:media_core_cast_dlna/src/infrastructure/discovery/ssdp/ssdp_constants.dart';

/// Builds M-SEARCH datagrams.
abstract final class SsdpSearch {
  /// Builds one M-SEARCH request for [searchTarget].
  ///
  /// MAN is required (`ssdp:discover`); MX bounds how long responders
  /// may stagger their replies, which on a busy network is what keeps a
  /// thousand responses from colliding on one socket read loop.
  static List<int> build(String searchTarget, {int mx = SsdpConstants.defaultMx}) {
    final request = [
      'M-SEARCH * HTTP/1.1',
      'HOST: ${SsdpConstants.multicastAddress}:${SsdpConstants.port}',
      'MAN: ${SsdpConstants.discoverMan}',
      'MX: $mx',
      'ST: $searchTarget',
      '',
      '',
    ].join('\r\n');
    return utf8.encode(request);
  }
}
