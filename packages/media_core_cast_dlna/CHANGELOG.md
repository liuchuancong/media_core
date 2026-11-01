## 0.8.0

Structured logging across the protocol core (TECHNICAL_DESIGN.md §25) plus the §25.3 diagnostics snapshot.

- `DlnaLog`: a pure-Dart log hub — `DlnaLogEvent` (category per §25.1: discovery/ssdp/description/soap/gena/media selection/media server/playback/session/compatibility; level per §25.2; message, error, fields, timestamp) delivered to a set-once process-wide sink. The default sink drops; a throwing sink never breaks the emitter.
- Instrumented: discovery lifecycle and device found/lost/re-resolved/description-failed; SOAP timeouts, unreachable endpoints and device-refused faults (with the UPnP error code); GENA subscribe/renewal-retry/exhaustion/unsubscribe; media server start/stop/failure; session connect/disconnect and the full recovery arc (warning on entry, error on exhaustion, info on recovery).
- `DlnaCastBackend` installs a process-wide bridge into media_core's `MediaCoreLog` (wire categories map to `network`, playback/session keep their own); standalone hosts assign `DlnaLog.sink` directly.
- `loggableUrl` strips query/fragment so media-server tokens never reach a sink (§22.5).

## 0.7.0

Phase 9 per TECHNICAL_DESIGN.md: the vendor compatibility layer.

- `DeviceCompatibilityProfile`: declares one vendor/model family's quirks as data — `instanceId`, `unquotedSoapAction`, `seekUnit`, `playSpeed`, `omitDidl` — matched against the device description (manufacturer/model/device type, never addresses). Every field defaults to the spec answer, so a spec-conformant device runs on the standard profile with zero configuration (§9 acceptance).
- `DeviceCompatibilityRegistry`: resolves the governing profile, registration order as priority, the standard profile as terminal fallback. Registering a new vendor touches no domain or protocol code.
- Wiring: the manager resolves the profile per device from an injectable registry (`DlnaSessionManager.compatibility`, surfaced through `DlnaClient.compatibility`); sessions hand it to their services. `AvTransportService` routes every action through a single quirks application point (`SOAPACTION` quote stripping, profile instance id, Seek unit, Play speed); `RenderingControlService` applies the profile instance id; `setMedia` sends an empty DIDL when the profile says the firmware rejects it.
- Fixed: quirks previously bypassed the actions that built their own envelopes (`play`/pause/stop/probes) — all AVTransport actions now share one quirks application path, verified per-quirk on the wire.

## 0.6.0

Phase 8 per TECHNICAL_DESIGN.md: RenderingControl (volume/mute), multi-device session management, and connection recovery.

- `RenderingControlService`: typed `GetVolume`/`SetVolume`/`GetMute`/`SetMute` on the Master channel with 0..100 clamping, optional SCPD-backed local refusal, and junk-answer tolerance. Sessions expose `setVolume`/`setMute` through the same serial command queue; applied values land on the playback snapshot (`volume`/`isMuted`), and GENA `Volume`/`Mute` variables merge when the device pushes them.
- Connection recovery (§20.4): `DlnaRecoveryPolicy` (enabled/maxAttempts/retryDelay, plus a `.disabled()` preset). Network-class failures (`DlnaTimeoutException`/`DlnaNetworkException`) arm a bounded recovery loop — re-resolve the device description (verifying the UDN, adopting moved endpoints), reload SCPDs, re-arm GENA against a fresh callback route, probe, then reconnect; media is never re-pushed without confirmation. Exhausting the budget fails the session; a disabled policy leaves the session untouched.
- `DlnaSessionManager` passes the policy through and owns the GENA factory so recovery can rebuild subscriptions against fresh callback routes; `DlnaClient.disconnect` unregisters the media it served for that session's device (§23.3 — the shared server stays up).
- The session's `device` now reflects the recovered description after a successful recovery.

## 0.5.0

Phase 7 per TECHNICAL_DESIGN.md: GENA event subscription with the polling fallback.

- GENA infrastructure: `GenaCallbackServer` serves the local callback endpoint with per-subscription token routes (§14.7, §22.4 — NOTIFY method only, unknown routes 404, bodies size-bounded); `GenaSubscriber` manages `SUBSCRIBE`/renewal/`UNSUBSCRIBE` with half-lifetime renewals, a three-strike renewal backoff that ends in a clean failed state, SID verification and SEQ deduplication on every event; `GenaMessageParser` decodes PropertySet bodies and unfolds AVT/RCS `LastChange` documents into flat variable maps.
- Session integration: sessions attach a subscriber when the device advertises `eventSubURL` and merge pushed variables (`TransportState`, positions, durations, track URI) straight into `DlnaPlaybackState`; a failed subscribe or exhausted renewals only degrade to the polling monitor (§14.7, §19.1) — the session keeps playing. Unsubscribe and callback-route cleanup happen with the session (§14.7 设备离线清理).
- `DlnaSessionManager` owns the shared callback server and GENA transport (both injectable; owned ones closed by `dispose`); `DlnaClient.enableGena` turns eventing off entirely.
- New `DlnaSubscriptionException`; `GenaHttpResponse`/`GenaTransport`/`GenaSubscription` exported alongside the subscriber.

## 0.4.0

Phase 6 per TECHNICAL_DESIGN.md: cast sessions with queued playback control and polled state sync.

- Sessions: `DlnaSession` (interface per §28) implemented by `DlnaSessionController` — per-session serial command queue (§18.5: `SetAVTransportURI` before `Play`, seeks serialize, `stop` cancels the queued backlog so dropped commands complete with `DlnaSessionException` instead of firing later), connection lifecycle (`DlnaConnectionState`), and a merged `DlnaPlaybackState` stream (`DlnaTransportState`, position, duration, current URI/title).
- State sync (§19): `DlnaPlaybackMonitor` polls `GetPositionInfo`/`GetTransportInfo` on state-adaptive cadences (playing 2s, paused 8s, idle never, both configurable); command follow-ups verify the device's actual state instead of trusting SOAP success (§18.3); one missed poll keeps the last snapshot rather than flashing unknown.
- `AvTransportService`: typed facade over the AVTransport actions (`setUri`/`play`/`pause`/`stop`/`seek`/`getTransportInfo`/`getPositionInfo`/`getMediaInfo`) with decoded answers; `NOT_IMPLEMENTED` fields read as absent.
- Seek guardrails (§13.5): negative or beyond-known-duration targets are rejected with `ArgumentError`, and an SCPD-loaded action set refuses undeclared actions locally via `DlnaUnsupportedActionException` — which exposed and fixed a real bug: `SoapClient`'s action-name extraction kept the SOAPAction closing quote, so every capability lookup missed by one character.
- Protocol-level DIDL: `DidlMetadata` builder (moved out of the adapter, which now delegates) with the media-type-derived object class; sessions build payloads through it.
- `DlnaSessionManager` (one active session per device) and `DlnaClient`, the public facade wiring discovery, sessions, capability preparation and the media server behind one object (§28).

## 0.3.0

Phase 4-5 per TECHNICAL_DESIGN.md: DLNA media capability negotiation and the HTTP media server, wired into the backend so local files cast end to end.

- Capability negotiation: `MediaProtocolInfo` parses the `protocol:network:contentFormat:additionalInfo` structure including the `DLNA.ORG_PN/OP/CI/FLAGS` parameters; `DlnaMediaCapability` models a device's sink declaration (unknown-capability sets stay permissive); `DlnaCapabilityResolver` reads it from `ConnectionManager.GetProtocolInfo` and degrades a failed probe to unknown instead of an error.
- Media selection: `DlnaMedia` / `DlnaMediaResource` / `DlnaMediaSelection` domain models plus `DlnaMediaSelector`, which scores resources on declared format, DLNA profile, byte-range support and conversion state. A known capability that rejects every resource raises `DlnaUnsupportedMediaException` with the per-resource reasons before anything is sent.
- HTTP media server (Phase 5): `MediaHttpServer` serves registered local files behind random per-resource tokens (`/{token}/{id}`, no path parameters, no directory listing, expiry sweeps), with HEAD, single-segment byte ranges (206/416 and correct `Content-Range`), streamed bodies and a bounded-response transport. `HttpByteRange` parses the media subset of the Range grammar; `IpAddressSelector` picks the LAN address URLs point at; `MimeType` maps extensions.
- Backend integration: `DlnaCastBackend.setMedia` now rewrites local files (`file://`, drive paths, UNC, POSIX absolute) through the media server, resolves the device's capability once per device, and refuses unsupported formats up front with a `CastException`. The DIDL `res` line carries the rewritten URL — the local path never leaves the machine. A host may inject its own `MediaHttpServer`; the lazily created default is stopped by `dispose()`.
- `SoapClient` maps unexpected transport errors to `DlnaNetworkException` instead of leaking raw transport exceptions.

## 0.2.0

Phase 0-3 per TECHNICAL_DESIGN.md: the flat backend becomes a layered, independent DLNA/UPnP protocol package (domain / application / infrastructure, with the media_core adapter kept as one seam).

- Layered core: `DlnaDevice` / `DlnaService` / `ServiceType` domain models; the `DlnaException` hierarchy (discovery / description / network / timeout / soap / UPnP, with `UpnpErrorCode` classification and retryability); `DlnaDiscoveryManager` with state streams (`devicesStream`, `deviceAdded`/`deviceUpdated`/`deviceRemoved`, `errors`), bounded description-fetch concurrency, per-device failure backoff and `refresh()`; `DlnaDeviceRegistry` preserving discovery order.
- SSDP: `SsdpClient` replaces `SsdpDiscovery` with multi-target search cycles (`MediaRenderer` v1 and v2, staggered per ST), `ssdp:update` handling and an exposed bound port; M-SEARCH building moves to `SsdpSearch`, wire constants to `SsdpConstants`.
- Description parsing: `DeviceDescriptionParser` outputs `DlnaDevice`, honors `URLBase`, aggregates embedded-device services and parses serviceId/SCPDURL/eventSubURL; new `ServiceDescriptionParser` reads SCPD actions, arguments and state variables for capability checks.
- SOAP: `Soap` splits into `SoapRequestBuilder` (Phase-3 actions plus a generic invoke), `SoapResponseParser`, `SoapFaultParser` and `SoapClient`, which maps timeouts to `DlnaTimeoutException`, socket failures to `DlnaNetworkException`, and UPnP faults to `DlnaUpnpException`/`DlnaUnsupportedActionException`, with an optional SCPD-backed local capability check.
- Auxiliary mDNS channel: `BonsoirDiscoveryChannel` (bonsoir ^7.1.6) emits `MDnsServiceHint`s; SSDP remains the primary discovery mechanism and an mDNS hint never qualifies a device by itself.
- Fixed: `readBoundedBody` re-listened a single-subscription stream when a body crossed the size limit (`Stream has already been listened to`) instead of throwing its `FormatException`.

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
