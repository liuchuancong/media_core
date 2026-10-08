## 0.1.0

Initial release.

- DLNA/UPnP casting backend: `DlnaCastBackend` implements media_core's protocol-neutral `MediaCastBackend` (id `dlna`), so `CastController` drives a TV without the core importing any protocol bytes.
- SSDP discovery: `SsdpDiscovery` sends M-SEARCH on a configurable interval, joins the multicast group when the interface allows it, parses `NOTIFY`/search responses via `SsdpMessage`, and expires devices on their own `CACHE-CONTROL: max-age` so a TV that silently left the network stops being offered.
- Device description parsing: `DlnaDeviceDescription.parse` reads UDN, friendly name, manufacturer and model plus the AVTransport/RenderingControl endpoints, resolving relative control URLs against the announcement location; a device with no AVTransport service is refused rather than listed.
- SOAP codec: `Soap` builds `SetAVTransportURI`, `Play`, `Pause`, `Stop`, `Seek`, `GetPositionInfo`, `GetTransportInfo`, `GetVolume` and `SetVolume` envelopes with spec-exact argument names and byte-accurate `Content-Length`, and decodes responses by local name so namespace prefixes do not matter; faults become `SoapFault` with UPnP `errorCode`/`errorDescription`.
- DIDL-Lite: `DidlLite.build` emits title, class, creator, album art and a `res` line whose `protocolInfo` carries a DLNA profile guessed from the MIME type.
- Command honesty: failures throw `CastException` with the device id and cause attached, while a position read on a silent device returns `CastPosition.unknown()` so a progress ring can gray out instead of crashing.
- Hardened HTTP transport: `HttpDescriptionFetcher` and `HttpSoapTransport` accept only http/https locations from SSDP, treat non-2xx as failure and bound response bodies via `maxCastResponseBodyBytes`.
- Injectable seams for testing without a network: `SsdpSource`, `DescriptionFetcher` and `SoapPoster`; `dispose()` closes only the clients this package created.
