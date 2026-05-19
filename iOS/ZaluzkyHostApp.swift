import SwiftUI

@main
struct ZaluzkyHostApp: App {
    @StateObject private var appState = IOSAppState()

    init() {
        // Boot WatchConnectivity so paired-Watch scene sync starts immediately.
        _ = SceneSync.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState)
        }
    }
}
