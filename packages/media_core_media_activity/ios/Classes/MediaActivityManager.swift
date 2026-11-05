import ActivityKit
import Foundation

/// The ActivityKit attributes shared with the host's Widget Extension.
///
/// The extension imports this pod and renders from exactly this type — the
/// plugin owns the data contract, the extension owns the pixels (spec §3,
/// §10). Static attributes carry what is stable per session; everything the
/// lyric view repaints lives in `ContentState`.
public struct MediaActivityAttributes: ActivityAttributes {
    /// What the lock screen shows while the system scales it down.
    public struct ContentState: Codable, Hashable {
        /// Lyric line currently on screen; empty shows track info only.
        public var currentLyric: String

        /// Preview of the following line; empty hides the row.
        public var nextLyric: String

        /// Whether playback is advancing.
        public var isPlaying: Bool

        /// Position at update time, in milliseconds (spec §6.1: no seconds).
        public var positionMs: Int64

        /// Playback speed; the lock screen drifts its clock by rate × Δt.
        public var playbackRate: Double

        /// Monotonic lyric revision; guards out-of-order updates.
        public var lyricRevision: Int64

        public init(
            currentLyric: String,
            nextLyric: String,
            isPlaying: Bool,
            positionMs: Int64,
            playbackRate: Double,
            lyricRevision: Int64
        ) {
            self.currentLyric = currentLyric
            self.nextLyric = nextLyric
            self.isPlaying = isPlaying
            self.positionMs = positionMs
            self.playbackRate = playbackRate
            self.lyricRevision = lyricRevision
        }
    }

    /// One playback session; duplicates are refused at the manager.
    public var sessionId: String

    /// Song (or stream) title.
    public var title: String

    /// Artist; empty when unknown.
    public var artist: String

    /// Album; nil for most live streams.
    public var album: String?

    /// Artwork file name inside the App Group artwork directory; nil shows
    /// the host's default artwork (spec §12: files, never base64).
    public var artworkKey: String?

    public init(
        sessionId: String,
        title: String,
        artist: String,
        album: String?,
        artworkKey: String?
    ) {
        self.sessionId = sessionId
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkKey = artworkKey
    }
}

/// ActivityKit lifecycle owner (spec §9).
///
/// Below iOS 16.1 every call reports `activity_not_supported` — the plugin
/// still loads, the feature reads as off, playback is untouched (spec
/// §13.3). The state-based `request`/`update`/`end` forms are used
/// deliberately: they are the iOS 16.1 surface, one version earlier than
/// the `Content`-based replacements (16.2).
///
/// `update` and `end` are async on the 16.1 surface; the manager returns its
/// acceptance synchronously and dispatches the mutation in a detached task.
/// The Dart sync policy (§8.4) already prevents high-frequency pushes, so
/// ordering inside ActivityKit stays deterministic.
final class MediaActivityManager {
    /// The one live activity, keyed by its session id. One activity per app
    /// is the working model (spec §7.2): switching tracks replaces.
    private var current: (sessionId: String, activity: Activity<MediaActivityAttributes>)?

    var capabilities: MediaActivityCapabilitiesReport {
        let major = Int64(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)

        guard #available(iOS 16.1, *) else {
            return MediaActivityCapabilitiesReport(
                isSupported: false,
                activitiesEnabled: false,
                frequentUpdatesEnabled: false,
                supportsDynamicIsland: false,
                systemMajorVersion: major
            )
        }

        let info = ActivityAuthorizationInfo()

        // The frequent-update toggle only exists from iOS 16.2; on 16.1 the
        // system applies its default budget instead (spec §13.2: unknown is
        // expressible, so the host decides "should we try").
        let frequentUpdates: Bool
        if #available(iOS 16.2, *) {
            frequentUpdates = info.frequentUpdatesEnabled
        } else {
            frequentUpdates = false
        }

        return MediaActivityCapabilitiesReport(
            isSupported: true,
            activitiesEnabled: info.areActivitiesEnabled,
            frequentUpdatesEnabled: frequentUpdates,
            supportsDynamicIsland: supportsDynamicIsland,
            systemMajorVersion: major
        )
    }

    /// Hardware fact, never derived from the iOS version (spec §13.2).
    /// ActivityKit does not expose island presence; the system simply omits
    /// the island views on devices without one, so "the API exists" is the
    /// honest report.
    var supportsDynamicIsland: Bool {
        if #available(iOS 16.1, *) {
            return true
        }

        return false
    }

    func startActivity(
        metadata: MediaActivityMetadata,
        initialState: MediaActivityContentState
    ) -> MediaActivityCallResult {
        guard #available(iOS 16.1, *) else {
            return MediaActivityCallResult(ok: false, errorCode: "activity_not_supported")
        }

        guard current == nil else {
            return MediaActivityCallResult(ok: false, errorCode: "activity_already_active")
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return MediaActivityCallResult(ok: false, errorCode: "activity_disabled")
        }

        let attributes = MediaActivityAttributes(
            sessionId: metadata.sessionId,
            title: metadata.title,
            artist: metadata.artist,
            album: metadata.album,
            artworkKey: metadata.artworkKey
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                state: toContentState(initialState),
                pushType: nil // Local updates only; lyrics need no APNs (spec §5)
            )
            current = (metadata.sessionId, activity)
            observeDisposal(of: activity, sessionId: metadata.sessionId)
        } catch {
            // A refused create degrades to normal playback (spec §13.3).
            return MediaActivityCallResult(ok: false, errorCode: "activity_creation_failed")
        }

        return MediaActivityCallResult(ok: true, errorCode: nil)
    }

    func updateActivity(
        sessionId: String,
        state: MediaActivityContentState
    ) -> MediaActivityCallResult {
        guard #available(iOS 16.1, *) else {
            return MediaActivityCallResult(ok: false, errorCode: "activity_not_supported")
        }

        guard let pair = current, pair.sessionId == sessionId else {
            return MediaActivityCallResult(ok: false, errorCode: "activity_not_found")
        }

        let contentState = toContentState(state)
        Task { await pair.activity.update(contentState) }

        return MediaActivityCallResult(ok: true, errorCode: nil)
    }

    func endActivity(sessionId: String) -> MediaActivityCallResult {
        guard #available(iOS 16.1, *) else {
            return MediaActivityCallResult(ok: false, errorCode: "activity_not_supported")
        }

        guard let pair = current, pair.sessionId == sessionId else {
            return MediaActivityCallResult(ok: false, errorCode: "activity_not_found")
        }

        current = nil
        // The lock screen may keep the final state briefly; ending is not
        // immediate removal (spec §9.4).
        Task { await pair.activity.end(dismissalPolicy: .immediate) }

        return MediaActivityCallResult(ok: true, errorCode: nil)
    }

    func endAllActivities() {
        guard #available(iOS 16.1, *) else {
            return
        }

        current = nil
        for activity in Activity<MediaActivityAttributes>.allActivities {
            Task { await activity.end(dismissalPolicy: .immediate) }
        }
    }

    func activityStatus(sessionId: String) -> MediaActivityStatusReport {
        guard #available(iOS 16.1, *) else {
            return MediaActivityStatusReport(isActive: false, isDismissed: false)
        }

        guard let pair = current, pair.sessionId == sessionId else {
            return MediaActivityStatusReport(isActive: false, isDismissed: false)
        }

        let state = pair.activity.activityState

        return MediaActivityStatusReport(
            isActive: state == .active,
            isDismissed: isDisposalState(state)
        )
    }

    /// Watch for the system (or the user) discarding the activity; Dart is
    /// told once so it stops pushing into a ghost (spec §9.5, §16).
    private func observeDisposal(
        of activity: Activity<MediaActivityAttributes>,
        sessionId: String
    ) {
        guard #available(iOS 16.1, *) else {
            return
        }

        Task { @MainActor in
            for await state in activity.activityStateUpdates where Self.isDisposalState(state) {
                if self.current?.sessionId == sessionId {
                    self.current = nil
                }
                MediaActivityCommandRoute.send {
                    try await MediaActivityPlugin.commandApi?.onActivityDismissed(sessionId: sessionId)
                }
                break
            }
        }
    }

    /// The user-removed / system-reclaimed states. `.ended` covers a call to
    /// `end`; `.dismissed` (16.2+) covers a user swipe or budget eviction.
    private static func isDisposalState(
        _ state: Activity<MediaActivityAttributes>.ActivityState
    ) -> Bool {
        if state == .ended {
            return true
        }

        if #available(iOS 16.2, *) {
            return state == .dismissed
        }

        return false
    }

    /// Pigeon struct -> ActivityKit ContentState. Total on purpose: a field
    /// added to one side without the other is a compile error here.
    private func toContentState(
        _ state: MediaActivityContentState
    ) -> MediaActivityAttributes.ContentState {
        MediaActivityAttributes.ContentState(
            currentLyric: state.currentLyric,
            nextLyric: state.nextLyric,
            isPlaying: state.isPlaying,
            positionMs: state.positionMs,
            playbackRate: state.playbackRate,
            lyricRevision: state.lyricRevision
        )
    }
}
