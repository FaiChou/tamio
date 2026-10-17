import SwiftUI
import TamioTerminal

/// Standalone native preview for UI verification, separate from Tamio's account storage.
@main
struct ConfigurationPreviewApp: App {
    var body: some Scene {
        #if os(macOS)
            WindowGroup("Tamio Configuration Preview") { GhosttyConfigurationView() }
                .defaultSize(width: 1280, height: 820)
        #else
            WindowGroup { NavigationStack { GhosttyConfigurationView() } }
        #endif
    }
}
