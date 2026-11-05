import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

// The shared data contract lives in the plugin's Shared subspec — the only
// module a Widget Extension may link (no Flutter, no bridge code, spec §10).
import media_core_media_activity

/// The lock-screen lyrics / Dynamic Island Live Activity.
///
/// Rendering rules (spec §10, §20.1.2): the extension owns the pixels and
/// nothing else — no playback state, no timers, no updates of its own. It
/// draws whatever the plugin pushed last; between pushes the position text
/// is a static snapshot, exactly like the system's own clock drift handled
/// by the activity (spec §8.1). No iOS 17-only interactive buttons here:
/// the demo targets the 16.1 surface (spec §13.2), so playback commands
/// come from the Now Playing card through MPRemoteCommandCenter instead.
struct MediaActivityLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MediaActivityAttributes.self) { context in
            // The lock screen presentation.
            LockScreenLyricsView(context: context)
        } dynamicIsland: { context in
            // The Dynamic Island presentation: compact while other apps
            // run, expanded when the viewer long-presses it.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ArtworkView(attributes: context.attributes)
                        .frame(width: 44, height: 44)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(context.attributes.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LyricsBlock(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .semibold))
            } compactTrailing: {
                Text(Self.positionText(context.state.positionMs))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }

    /// mm:ss, whole seconds; the bridge carries whole milliseconds (§6.1).
    static func positionText(_ positionMs: Int64) -> String {
        let totalSeconds = positionMs / 1000

        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

/// The lock screen view: track identity up top, the lyric as the hero text,
/// the next line as a quiet preview (spec §16).
struct LockScreenLyricsView: View {
    /// The activity context pushed by the plugin.
    let context: ActivityViewContext<MediaActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ArtworkView(attributes: context.attributes)
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text(context.attributes.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tint)
            }

            LyricsBlock(state: context.state)

            HStack {
                Text(
                    MediaActivityLiveActivityWidget.positionText(context.state.positionMs)
                )
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                Spacer()
                // Rev is the guard against out-of-order pushes (§6.2); shown
                // tiny so a debugging session can see updates land.
                Text("rev \(context.state.lyricRevision)")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
    }
}

/// The current and next lyric lines; the heart of the feature.
struct LyricsBlock: View {
    /// The dynamic content the plugin pushed last.
    let state: MediaActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if state.currentLyric.isEmpty {
                // No lyric for this track: show track info only (spec §16).
                Text("♪")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text(state.currentLyric)
                    .font(.system(size: 19, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            if !state.nextLyric.isEmpty {
                Text(state.nextLyric)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// The artwork from the App Group file hand-off (spec §12).
///
/// `artworkKey` names a file the app wrote into the App Group container; nil
/// (the demo's case) falls back to a neutral glyph. The read is synchronous
/// and uncached — fine for a demo, a real host caches per key and cleans up
/// through the plugin's artwork store.
struct ArtworkView: View {
    /// The static attributes carrying the artwork key.
    let attributes: MediaActivityAttributes

    var body: some View {
        if let key = attributes.artworkKey,
           let url = MediaActivityAttributes.artworkURL(forKey: key),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
        }
    }
}
