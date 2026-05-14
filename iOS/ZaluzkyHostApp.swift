import SwiftUI

@main
struct ZaluzkyHostApp: App {
    @StateObject private var appState = IOSAppState()

    var body: some Scene {
        WindowGroup {
            if appState.isSignedIn {
                SignedInView(appState: appState)
            } else {
                LoginView(appState: appState)
            }
        }
    }
}
