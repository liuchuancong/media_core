import Foundation
import MediaPlayer

/// Remote command owner (spec §11.2): `MPRemoteCommandCenter` only.
///
/// Every command routes to Dart through the Pigeon callback API — Swift
/// never keeps playback state and never acts on its own (spec §20.1.7).
/// Commands the host disables are removed rather than erroring, and a live
/// stream typically disables next/previous/seek (spec §11.2).
///
/// The generated api methods are `@MainActor async throws`, so handlers
/// respond to the system immediately (`.success` = "delivered") and forward
/// to Dart through `MediaActivityCommandRoute`, which swallows transport
/// errors (spec §13.3).
final class MediaRemoteCommandManager {
    private let commandApi: MediaActivityCommandApi

    /// The player id echoed back on every command. Single-player hosts leave
    /// it empty; multi-player hosts set it through `configureRemoteCommands`
    /// before going live. Read at command time, never captured stale.
    private var playerId = ""

    private var handlersInstalled = false

    init(commandApi: MediaActivityCommandApi) {
        self.commandApi = commandApi
    }

    /// Installs the command handlers once. Idempotent: re-registration must
    /// not stack handlers (spec §17.2).
    func install() {
        guard !handlersInstalled else {
            return
        }
        handlersInstalled = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { _ in
            MediaActivityCommandRoute.send { try await self.commandApi.onPlay(playerId: self.playerId) }
            return .success
        }

        center.pauseCommand.addTarget { _ in
            MediaActivityCommandRoute.send { try await self.commandApi.onPause(playerId: self.playerId) }
            return .success
        }

        center.togglePlayPauseCommand.addTarget { _ in
            MediaActivityCommandRoute.send { try await self.commandApi.onTogglePlayPause(playerId: self.playerId) }
            return .success
        }

        center.nextTrackCommand.addTarget { _ in
            MediaActivityCommandRoute.send { try await self.commandApi.onNextTrack(playerId: self.playerId) }
            return .success
        }

        center.previousTrackCommand.addTarget { _ in
            MediaActivityCommandRoute.send { try await self.commandApi.onPreviousTrack(playerId: self.playerId) }
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let positionMs = Int64(positionEvent.positionTime * 1000.0)
            MediaActivityCommandRoute.send {
                try await self.commandApi.onSeek(playerId: self.playerId, positionMs: positionMs)
            }

            return .success
        }
    }

    func uninstall() {
        guard handlersInstalled else {
            return
        }
        handlersInstalled = false

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
    }

    /// Enables/disables commands per the host's current playback reality
    /// (spec §11.2). Disabled commands disappear from the lock screen
    /// instead of failing. The generated config carries no player id — a
    /// single-player host needs nothing more; a multi-player host routes the
    /// echoed [playerId] (currently "") itself.
    func configure(_ config: RemoteCommandConfig) {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = config.playPauseEnabled
        center.pauseCommand.isEnabled = config.playPauseEnabled
        center.togglePlayPauseCommand.isEnabled = config.playPauseEnabled
        center.nextTrackCommand.isEnabled = config.nextTrackEnabled
        center.previousTrackCommand.isEnabled = config.previousTrackEnabled
        center.changePlaybackPositionCommand.isEnabled = config.seekEnabled
    }
}
