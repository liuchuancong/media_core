import WidgetKit
import SwiftUI

/// The entry point of the Widget Extension.
///
/// Xcode creates a bundle of its own when you add the target; replace its
/// contents with this so the bundle lists exactly the media activity widget.
/// The target name this file ships in is `MediaActivityWidgetExtension`,
/// which the Podfile block expects (see README step 4).
@main
struct MediaActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        MediaActivityLiveActivityWidget()
    }
}
