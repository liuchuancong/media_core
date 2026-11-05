import ActivityKit
import Foundation

/// The ActivityKit attributes shared with the host's Widget Extension.
///
/// The extension imports this pod and renders from exactly this type — the
/// plugin owns the data contract, the extension owns the pixels (spec §3,
/// §10). Static attributes carry what is stable per session; everything the
/// lyric view repaints lives in `ContentState`.
///
/// This file lives in the pod's `Shared` subspec on purpose: it is the only
/// thing a Widget Extension may link. It imports ActivityKit and Foundation
/// and nothing else — no Flutter, no generated bridge code — so the
/// extension target (which has no Flutter runtime) compiles it cleanly:
///
/// ```ruby
/// pod 'media_core_media_activity/Shared'
/// ```
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

/// The App Group id every surface of this feature shares (spec §12.2).
///
/// The Runner writes artwork files here; the Widget Extension reads them and
/// must carry the same group in its entitlements. Change it in one place —
/// this constant — and mirror it into both entitlement files and the
/// extension's own artwork loading code.
public extension MediaActivityAttributes {
    /// App Group container id used for the artwork hand-off directory.
    static let appGroupId = "group.media_core.media_activity"

    /// Sub-path of the App Group container holding the artwork files.
    static let artworkDirectory = "MediaActivity/Artwork"

    /// The full artwork file URL for [key], or nil outside the App Group
    /// (a missing entitlement, mostly). The extension's artwork loader uses
    /// this; the plugin's `MediaActivityArtworkStore` keeps its own path
    /// building in sync with these constants.
    static func artworkURL(forKey key: String) -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else {
            return nil
        }

        return container
            .appendingPathComponent(artworkDirectory, isDirectory: true)
            .appendingPathComponent(key)
    }
}
