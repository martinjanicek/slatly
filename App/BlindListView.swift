import SwiftUI
import OverkizKit

struct BlindListView: View {
    let client: OverkizClient
    let onSignOut: () -> Void

    @StateObject private var sceneStore = SceneStore.shared
    @State private var devices: [OverkizDevice] = []
    @State private var loadingError: String?
    @State private var isLoading = true
    @State private var showingSignOutConfirm = false
    @State private var runningSceneID: BlindScene.ID?
    @State private var lastRunFailedID: BlindScene.ID?
    @State private var runningMyAll = false
    @State private var runningStopAll = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().controlSize(.regular)
            } else if let err = loadingError {
                errorState(err)
            } else {
                blindsList
            }
        }
        .navigationTitle("Slatly")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSignOutConfirm = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog(
            "Sign out?",
            isPresented: $showingSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { onSignOut() }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            sceneStore.refresh()
            await load()
        }
    }

    private var blindsList: some View {
        List {
            // 1. Rooms — All + individual blinds (no separate global-controls row;
            //    'My all' lives down with the scene tiles where everything tap-runnable is grouped.)
            Section {
                NavigationLink(value: AllBlindsRoute()) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(.tint.opacity(0.2))
                            Image(systemName: "rectangle.3.group.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.tint)
                        }
                        .frame(width: 14, height: 14)
                        Text("All").fontWeight(.semibold)
                    }
                }
                ForEach(devices.filter(\.isBlind)) { device in
                    NavigationLink(value: device) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(BlindThemeStore.theme(for: device.deviceURL).swatch)
                                .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                                .frame(width: 14, height: 14)
                            Text(displayName(for: device))
                                .lineLimit(1)
                        }
                    }
                }
            }

            // 2. Quick-run tiles at the bottom: user scenes + a permanent
            //    'My all' tile (gold) that fires the My command on every blind.
            Section {
                tilesGrid
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            } header: {
                Text("Scenes")
            }
        }
        .navigationDestination(for: AllBlindsRoute.self) { _ in
            BulkTiltView(client: client, devices: devices.filter(\.isBlind))
        }
        .navigationDestination(for: OverkizDevice.self) { device in
            TiltView(client: client, device: device)
        }
    }

    private enum Tile: Identifiable {
        case scene(BlindScene)
        case myAll
        case stopAll

        var id: String {
            switch self {
            case .scene(let s): return "scene-\(s.id.uuidString)"
            case .myAll: return "_myAll"
            case .stopAll: return "_stopAll"
            }
        }
    }

    private var tileItems: [Tile] {
        sceneStore.scenes.map(Tile.scene) + [.myAll, .stopAll]
    }

    @ViewBuilder
    private var tilesGrid: some View {
        let items = tileItems
        let rows = stride(from: 0, to: items.count, by: 2).map { startIndex in
            Array(items[startIndex..<min(startIndex + 2, items.count)])
        }
        VStack(spacing: 6) {
            ForEach(0..<rows.count, id: \.self) { rowIdx in
                HStack(spacing: 6) {
                    ForEach(rows[rowIdx]) { item in
                        tile(item)
                    }
                    if rows[rowIdx].count == 1 {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ item: Tile) -> some View {
        switch item {
        case .scene(let scene):
            sceneTile(scene)
        case .myAll:
            myAllTile()
        case .stopAll:
            stopAllTile()
        }
    }

    private func sceneTile(_ scene: BlindScene) -> some View {
        Button {
            Task { await runScene(scene) }
        } label: {
            ZStack {
                VStack(spacing: 4) {
                    Image(systemName: scene.iconSystemName)
                        .font(.system(size: 18, weight: .semibold))
                    Text(scene.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.gradient)
                )
                .opacity(runningSceneID == scene.id ? 0.7 : 1.0)

                if runningSceneID == scene.id {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                } else if lastRunFailedID == scene.id {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(.red))
                        .offset(x: 28, y: -16)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(anyBusy)
    }

    private func myAllTile() -> some View {
        Button {
            Task { await sendMyAll() }
        } label: {
            ZStack {
                VStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("My all")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.yellow.gradient)
                )
                .opacity(runningMyAll ? 0.7 : 1.0)

                if runningMyAll {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.black)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(anyBusy)
    }

    private func stopAllTile() -> some View {
        Button {
            Task { await sendStopAll() }
        } label: {
            ZStack {
                VStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Stop all")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.gradient)
                )
                .opacity(runningStopAll ? 0.7 : 1.0)

                if runningStopAll {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(anyBusy)
    }

    private var anyBusy: Bool { runningSceneID != nil || runningMyAll || runningStopAll }

    @ViewBuilder
    private func errorState(_ err: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(err)
                .font(.caption2)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await load() } }
                .font(.caption)
            Button("Sign out") { onSignOut() }
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }

    private func runScene(_ scene: BlindScene) async {
        runningSceneID = scene.id
        let failed = await SceneRunner.run(scene, client: client)
        runningSceneID = nil
        lastRunFailedID = failed ? scene.id : nil
        if !failed {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if lastRunFailedID == scene.id { lastRunFailedID = nil }
            }
        }
    }

    private func sendMyAll() async {
        runningMyAll = true
        let blinds = devices.filter(\.isBlind)
        await withTaskGroup(of: Void.self) { group in
            for d in blinds {
                let url = d.deviceURL
                group.addTask { _ = try? await client.my(deviceURL: url) }
            }
        }
        runningMyAll = false
    }

    private func sendStopAll() async {
        runningStopAll = true
        let blinds = devices.filter(\.isBlind)
        await withTaskGroup(of: Void.self) { group in
            for d in blinds {
                let url = d.deviceURL
                group.addTask { _ = try? await client.stop(deviceURL: url) }
            }
        }
        runningStopAll = false
    }

    private func load() async {
        isLoading = true
        loadingError = nil
        do {
            devices = try await client.getDevices()
        } catch {
            loadingError = friendlyMessage(for: error)
        }
        isLoading = false
    }

    private func friendlyMessage(for error: Error) -> String {
        if let ok = error as? OverkizError {
            switch ok {
            case .badCredentials: return String(localized: "Wrong password")
            case .noAccessToken: return String(localized: "Token unavailable")
            case .http(let status, _): return String(localized: "HTTP \(status)")
            case .decoding: return String(localized: "Response parsing error")
            case .unexpectedResponse: return String(localized: "Unexpected response")
            }
        }
        return "\(error)"
    }
}
