import Foundation
import UIKit

/// Artwork hand-off between the app and the Widget Extension (spec §12).
///
/// Flutter decodes the cover, writes a scaled file named by content hash
/// into the App Group artwork directory, and passes only the *key* across
/// the bridge — no base64, no network in the extension, no Flutter memory
/// objects (spec §12.1, §12.2). This store reads those files for the
/// system surfaces and cleans up ones no live activity references.
struct MediaActivityArtworkStore {
    /// App Group id the host must add to both the Runner and the Widget
    /// Extension entitlements (spec §12.2). Shared with the extension through
    /// `MediaActivityAttributes.appGroupId` so both sides cannot drift.
    private let appGroupId: String

    init(appGroupId: String = MediaActivityAttributes.appGroupId) {
        self.appGroupId = appGroupId
    }

    /// The artwork directory inside the App Group container, creating it on
    /// first use. Exposed so the host's Flutter side can write into the same
    /// directory this store reads from.
    func directoryURL() -> URL? {
        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupId
            )
        else {
            return nil
        }

        let directory = container.appendingPathComponent(
            MediaActivityAttributes.artworkDirectory,
            isDirectory: true
        )

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }

    /// Reads one artwork file. Returns nil on any miss — the caller keeps
    /// its previous artwork instead (spec §13.3: missing artwork degrades).
    func read(_ key: String) -> UIImage? {
        guard
            let directory = directoryURL(),
            // The key crosses the bridge; refuse anything that smells like a
            // path traversal before it reaches the filesystem.
            isValidKey(key),
            let data = try? Data(contentsOf: directory.appendingPathComponent(key))
        else {
            return nil
        }

        return UIImage(data: data)
    }

    /// Deletes artwork files no live activity references. Cleanup is
    /// conservative: [keepKeys] are the keys of currently running activities
    /// (spec §12.2: never delete a file still in use).
    func cleanup(keeping keepKeys: Set<String>) {
        guard let directory = directoryURL(),
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else {
            return
        }

        for file in files where !keepKeys.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func isValidKey(_ key: String) -> Bool {
        !key.isEmpty
            && !key.contains("/")
            && !key.contains("..")
            && key.hasPrefix("artwork_")
    }
}
