import SwiftUI

@main
struct ZaluzkyApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let client = appState.client {
                    NavigationStack {
                        BlindListView(client: client, onSignOut: appState.signOut)
                    }
                } else {
                    LoginView(appState: appState)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    appState.refreshFromKeychain()
                }
            }
        }
    }
}
