/// The UPnP control error codes a device can answer an action with.
///
/// Values come from the UPnP AVTransport/RenderingControl control
/// specs. They must stay distinct from network faults: a 701 means the
/// TV is alive and refusing, a timeout means nobody answered — retry
/// policy and user messages differ completely between the two.
enum UpnpErrorCode {
  /// 401 — the action name is not implemented by the device.
  invalidAction(401),

  /// 402 — an argument is missing or out of range.
  invalidArgs(402),

  /// 501 — the action failed on the device.
  actionFailed(501),

  /// 701 — the requested transition is not available in the current
  /// transport state (e.g. Pause while stopped).
  transitionUnavailable(701),

  /// 702 — no media is loaded.
  noContents(702),

  /// 703 — the device cannot read the media source.
  readError(703),

  /// 704 — the media format is not supported by this renderer.
  formatNotSupported(704),

  /// 705 — the transport is locked by another control point.
  transportLocked(705),

  /// Any code the package does not map explicitly.
  unknown(0);

  /// Creates a code.
  const UpnpErrorCode(this.rawValue);

  /// The numeric UPnP error code (`0` only for [unknown]).
  final int rawValue;

  /// Maps a wire code onto the enum; anything unrecognized becomes
  /// [unknown] rather than throwing — devices invent codes.
  static UpnpErrorCode fromRaw(int? value) {
    for (final code in values) {
      if (code.rawValue == value && code != unknown) {
        return code;
      }
    }
    return unknown;
  }
}
