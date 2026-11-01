/// Tunables of a discovery run.
final class DlnaDiscoveryOptions {
  /// Creates options.
  const DlnaDiscoveryOptions({
    this.searchInterval = const Duration(seconds: 12),
    this.mx = 3,
    this.descriptionTimeout = const Duration(seconds: 8),
    this.maxConcurrentDescriptions = 4,
    this.descriptionFailureBackoff = const Duration(seconds: 60),
    this.requireAvTransport = true,
  });

  /// How often the search cycle repeats, refreshing every cache clock.
  final Duration searchInterval;

  /// The MX window each M-SEARCH advertises.
  final int mx;

  /// The budget for one device description fetch.
  final Duration descriptionTimeout;

  /// How many description fetches may run at once.
  ///
  /// A floor of TVs announcing simultaneously must not turn into a
  /// simultaneous burst of HTTP GETs from this process.
  final int maxConcurrentDescriptions;

  /// How long a device whose description fetch failed stays off the
  /// re-fetch list.
  ///
  /// A device that announces on every cache cycle but serves a broken
  /// description would otherwise be re-fetched on every alive message —
  /// one HTTP GET per announcement per device, forever. The entry is a
  /// backoff, not a ban: after it expires the device gets one more
  /// chance, because a TV rebooting mid-fetch is not a broken TV.
  final Duration descriptionFailureBackoff;

  /// Whether only devices exposing AVTransport are surfaced.
  ///
  /// On by default: a device that cannot accept a cast is a dead row
  /// in a picker. Media servers (storage-only) then stay invisible.
  final bool requireAvTransport;
}
