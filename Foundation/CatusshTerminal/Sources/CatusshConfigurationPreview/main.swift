import SwiftUI
import CatusshTerminal

/// Standalone native preview for UI verification, separate from catussh's account storage.
@main
struct ConfigurationPreviewApp: App {
    var body: some Scene {
        #if os(macOS)
            WindowGroup("catussh Configuration Preview") { GhosttyConfigurationView() }
                .defaultSize(width: 1280, height: 820)
        #else
            WindowGroup { NavigationStack { GhosttyConfigurationView() } }
        #endif
    }
}
