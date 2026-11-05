import Flutter
import UIKit

/// The iOS plugin for media_core_media_activity.
///
/// Registration wires four collaborators behind one Pigeon API:
///
/// - `MediaActivityManager` — ActivityKit lifecycle (lock screen / island)
/// - `MediaNowPlayingManager` — MPNowPlayingInfoCenter
/// - `MediaRemoteCommandManager` — MPRemoteCommandCenter, callbacks routed
///   back to Dart through the generated `MediaActivityCommandApi`
/// - `MediaActivityArtworkStore` — the App Group artwork container
///
/// The plugin defines the shared `MediaActivityAttributes` (in
/// `MediaActivityManager.swift`): the host's Widget Extension imports this
/// pod and renders from that type — the extension owns the pixels, the
/// plugin owns the data (spec §3, §10).
public class MediaActivityPlugin: NSObject, FlutterPlugin {
    /// Callback bridge to Dart; set during registration before any command
    /// can arrive (registration happens on the platform thread at startup).
    /// Module-internal so `MediaActivityManager` can route dismissal events.
    static var commandApi: MediaActivityCommandApi?

    private var activityManager: MediaActivityManager?
    private var remoteCommandManager: MediaRemoteCommandManager?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let commandApi = MediaActivityCommandApi(binaryMessenger: registrar.messenger())
        Self.commandApi = commandApi

        let artworkStore = MediaActivityArtworkStore()
        let nowPlayingManager = MediaNowPlayingManager(artworkStore: artworkStore)
        let remoteCommandManager = MediaRemoteCommandManager(commandApi: commandApi)
        let activityManager = MediaActivityManager()

        let api = MediaActivityBridge(
            activityManager: activityManager,
            nowPlayingManager: nowPlayingManager,
            remoteCommandManager: remoteCommandManager
        )

        MediaActivityApiSetup.setUp(binaryMessenger: registrar.messenger(), api: api)
        remoteCommandManager.install()
    }

    public func detach(from registrar: FlutterPluginRegistrar) {
        activityManager?.endAllActivities()
        remoteCommandManager?.uninstall()
        Self.commandApi = nil
    }
}

/// Routes Swift-originated callbacks (remote commands, dismissal events)
/// onto the main actor, where the generated FlutterApi lives. Every method
/// on the generated api is `async throws`; failures are swallowed here —
/// a command that cannot reach Dart is a lost notification, never a
/// playback failure (spec §13.3).
enum MediaActivityCommandRoute {
    static func send(_ body: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor in
            do {
                try await body()
            } catch {
                // Swallowed on purpose (see doc comment above).
            }
        }
    }
}

/// The Pigeon `MediaActivityApi` implementation: pure routing, no policy.
///
/// Availability discipline: every ActivityKit touch sits behind
/// `MediaActivityManager`, which no-ops below iOS 16.1 and reports
/// `activity_not_supported` — the plugin still loads on older systems.
///
/// Every protocol method is `throws` because Pigeon converts a thrown error
/// into a FlutterError; the hand-written layer chooses stable error codes
/// instead, so nothing here actually throws.
final class MediaActivityBridge: MediaActivityApi {
    private let activityManager: MediaActivityManager
    private let nowPlayingManager: MediaNowPlayingManager
    private let remoteCommandManager: MediaRemoteCommandManager

    init(
        activityManager: MediaActivityManager,
        nowPlayingManager: MediaNowPlayingManager,
        remoteCommandManager: MediaRemoteCommandManager
    ) {
        self.activityManager = activityManager
        self.nowPlayingManager = nowPlayingManager
        self.remoteCommandManager = remoteCommandManager
    }

    func getCapabilities() throws -> MediaActivityCapabilitiesReport {
        activityManager.capabilities
    }

    func startActivity(
        metadata: MediaActivityMetadata,
        initialState: MediaActivityContentState
    ) throws -> MediaActivityCallResult {
        activityManager.startActivity(metadata: metadata, initialState: initialState)
    }

    func updateActivity(sessionId: String, state: MediaActivityContentState) throws -> MediaActivityCallResult {
        activityManager.updateActivity(sessionId: sessionId, state: state)
    }

    func endActivity(sessionId: String) throws -> MediaActivityCallResult {
        activityManager.endActivity(sessionId: sessionId)
    }

    func endAllActivities() throws {
        activityManager.endAllActivities()
    }

    func getActivityState(sessionId: String) throws -> MediaActivityStatusReport {
        activityManager.activityStatus(sessionId: sessionId)
    }

    func updateNowPlaying(metadata: NowPlayingMetadata) throws {
        nowPlayingManager.update(metadata)
    }

    func clearNowPlaying() throws {
        nowPlayingManager.clear()
    }

    func configureRemoteCommands(config: RemoteCommandConfig) throws {
        remoteCommandManager.configure(config)
    }
}
