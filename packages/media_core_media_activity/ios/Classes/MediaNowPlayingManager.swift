import Foundation
import MediaPlayer

/// Now Playing owner (spec §11.1): `MPNowPlayingInfoCenter` only.
///
/// Distinct duty from the Live Activity on purpose (spec §20.1.5, §20.1.6):
/// the activity shows lyrics, this shows the system media card. Live streams
/// never fake music progress — duration stays nil and elapsed time is not
/// set while `isLive` (spec §11.1).
final class MediaNowPlayingManager {
    private let artworkStore: MediaActivityArtworkStore

    /// Cache of the last artwork key turned into `MPMediaItemArtwork`, so a
    /// stream of identical updates does not re-decode the file (spec §17.2).
    private var lastArtworkKey: String?
    private var lastArtwork: MPMediaItemArtwork?

    init(artworkStore: MediaActivityArtworkStore) {
        self.artworkStore = artworkStore
    }

    func update(_ metadata: NowPlayingMetadata) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: metadata.title,
            MPMediaItemPropertyArtist: metadata.artist,
            MPNowPlayingInfoPropertyPlaybackRate: metadata.playbackRate,
            MPNowPlayingInfoPropertyIsLiveStream: metadata.isLive,
        ]

        if let album = metadata.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        if !metadata.isLive {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
                Double(metadata.positionMs) / 1000.0
            if let durationMs = metadata.durationMs {
                info[MPMediaItemPropertyPlaybackDuration] = Double(durationMs) / 1000.0
            }
        }

        if let key = metadata.artworkKey {
            info[MPMediaItemPropertyArtwork] = artwork(for: key)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        // Keep the decoded artwork cache: keys are content hashes, so a
        // replayed track can reuse it (spec §17.2).
    }

    private func artwork(for key: String) -> MPMediaItemArtwork? {
        if key == lastArtworkKey, let cached = lastArtwork {
            return cached
        }

        guard let image = artworkStore.read(key) else {
            return lastArtwork // Missing artwork keeps the previous one (spec §13.3)
        }

        let item = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        lastArtworkKey = key
        lastArtwork = item

        return item
    }
}
