## Unreleased

- **Bug fix**: an engine that does not announce what it did is now watched like one that does. The position heartbeat already corrected the *mirrored* playback state from the adapter's own truth, and never told the watchdogs — so after a line switch or a recovery reopen (which cancels the observations) a state-latched engine, mpv among them, left the watchdogs believing playback was not running on a stream whose position was advancing. Both directions of that disagreement cost something: a source-ready stall fired seconds into a healthy stream and the recovery burned a single-use signed line to fix nothing, while the position-stall detector — the only one every engine can support, and the one that matters when a stream really does freeze — refused to arm because "playback is not running". The engine's own answer is now adopted once, for both readers of it, at the verified commit and on every heartbeat.
- **Bug fix**: a candidate that passed verification is reported as playing. The sweep wrote `buffering` unconditionally after verifying, which on an engine switch sat directly on top of the truth `attach` had just seeded from the adapter — so every consumer that trusts the mirror showed a spinner over a stream that had already started, until the next position heartbeat corrected it. `buffering` stays as the floor for an engine that has not said anything yet.
- `LiveWatchdogs.dispose()` now takes the position-stall timer down with the rest. It cancelled four of the five and was written before that one existed, so a disposed bundle kept a timer alive for a full `positionStallTimeout` — harmless to the detections (they are generation-guarded) and not harmless to a host that creates a controller per room.
- `LiveSourceRequest.title` has a reader. It was documented as the display title for events and read by nothing: the terminal failure and the exhausted-sweep log now carry it, which is the sentence it was written for — a host with several rooms open cannot tell them apart from a candidate URL.
- **Behaviour**: a signed live URL's query no longer reaches the logs or the failure message. The sweep wrote the full address of every candidate it tried, and the query of such a URL *is* the signature the platform handed out; the same reasoning already governs the recording manifest. Host and path still say which line failed, which is all those lines ask about.
- The `allowEngineFallback` doc is corrected to what the code, the class doc and the tests already said: `null` means allowed, for every shape of request — a single-URL request still gets the next engine on the same address, because a decoder that cannot open a stream is not the stream's fault. It used to claim a single-source request refused escalation, which a caller could only read as "my one line will not switch engines".
- Tests: three new — a verified candidate is reported playing rather than buffering, a reopen on a silent engine keeps the stall detector armed and does not reopen a healthy stream, and the failure names the room without repeating the signature. `FakePlayerAdapter` gained `announcesPlaying: false`, which is the state-latched engine these tests need and had no way to be.


- **Conformed to media_core's new signatures**: the live controller, pipeline and watchdogs call `setMute(muted:)`, `setAudioOnly(audioOnly:)`, `setBuffering(buffering:)` and read `PlayerKernel.presentationDriver` as assigned rather than attached, and the package's own boolean parameters became named. Public members are documented.

## 0.1.0

Initial release.

- Orchestration for non-seekable live streams: this package does not use `media_core`'s recovery ladder for on-demand playback — it decides what to switch and when.
- Line and engine sweep: a failing line is replaced by the next one; once lines run out the engine changes, so engine and line advance in pairs.
- Stall watchdog: the only criterion is whether the position advances (not each engine's own heartbeat), so a stall starts recovery; `LiveStallKind` classifies the stall and `LiveWatchdogRecoveryAction` names the action taken.
- Backoff retry: repeated failures retry on a backoff schedule instead of hammering the origin.
- Single-use URLs: signed URLs are one-shot, so hosts plug a refresh into both places the sweep can outlive them — `EngineFallbackSourceResolver` before an engine switch, `RecoverySourceResolver` before a recovery re-open.
- Serialization: the whole live chain runs on a single-slot task queue, so two switches can never race.
