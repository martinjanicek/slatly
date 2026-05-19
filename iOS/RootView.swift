import SwiftUI
import OverkizKit

struct RootView: View {
    @ObservedObject var appState: IOSAppState

    /// Tab selection that the URL handler can flip.
    @State private var selection: Tab = .dashboard

    enum Tab: Hashable { case dashboard, blinds, scenes, settings }

    var body: some View {
        Group {
            if let client = appState.client {
                TabView(selection: $selection) {
                    DashboardView(client: client)
                        .tabItem {
                            Label("Dashboard", systemImage: "slider.horizontal.3")
                        }
                        .tag(Tab.dashboard)

                    BlindListView(client: client)
                        .tabItem {
                            Label("Rooms", systemImage: "blinds.horizontal.closed")
                        }
                        .tag(Tab.blinds)

                    ScenesView(client: client)
                        .tabItem {
                            Label("Scenes", systemImage: "sparkles")
                        }
                        .tag(Tab.scenes)

                    SettingsView(appState: appState)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(Tab.settings)
                }
            } else {
                LoginView(appState: appState)
            }
        }
        .onOpenURL { url in
            handle(url)
        }
    }

    private func handle(_ url: URL) {
        guard url.scheme == "slatly" || url.scheme == "zaluzky" else { return }
        switch url.host {
        case "dashboard": selection = .dashboard
        case "blinds": selection = .blinds
        case "scenes": selection = .scenes
        case "settings": selection = .settings
        default: break
        }
    }
}
