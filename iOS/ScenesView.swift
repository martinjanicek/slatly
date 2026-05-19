import SwiftUI
import OverkizKit

struct ScenesView: View {
    let client: OverkizClient

    @StateObject private var store = SceneStore.shared
    @State private var devices: [OverkizDevice] = []
    @State private var loadingDevices = true
    @State private var loadError: String?
    @State private var editing: BlindScene?
    @State private var creating = false
    @State private var runningSceneID: BlindScene.ID?
    @State private var lastRunFailedID: BlindScene.ID?

    var body: some View {
        NavigationStack {
            Group {
                if loadingDevices {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    errorState(err)
                } else {
                    sceneList
                }
            }
            .navigationTitle("Scenes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        creating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(devices.filter(\.isBlind).isEmpty)
                }
            }
        }
        .task {
            store.refresh()
            if devices.isEmpty { await loadDevices() }
        }
        .sheet(isPresented: $creating) {
            SceneEditorView(
                devices: devices.filter(\.isBlind),
                existing: nil
            ) { newScene in
                store.upsert(newScene)
            }
        }
        .sheet(item: $editing) { scene in
            SceneEditorView(
                devices: devices.filter(\.isBlind),
                existing: scene
            ) { updated in
                store.upsert(updated)
            }
        }
    }

    @ViewBuilder
    private var sceneList: some View {
        if store.scenes.isEmpty {
            emptyState
        } else {
            List {
                ForEach(store.scenes) { scene in
                    sceneRow(scene)
                }
                .onDelete { store.delete(at: $0) }
                .onMove { store.move(from: $0, to: $1) }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func sceneRow(_ scene: BlindScene) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: scene.iconSystemName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(scene.name).fontWeight(.medium)
                Text("\(scene.steps.count) blinds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusIndicator(for: scene)
            Button {
                Task { await run(scene) }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(runningSceneID == scene.id)
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = scene }
        .swipeActions(edge: .leading) {
            Button {
                Task { await run(scene) }
            } label: {
                Label("Run", systemImage: "play.fill")
            }
            .tint(.green)
        }
    }

    @ViewBuilder
    private func statusIndicator(for scene: BlindScene) -> some View {
        if runningSceneID == scene.id {
            ProgressView().controlSize(.small)
        } else if lastRunFailedID == scene.id {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        } else {
            Color.clear.frame(width: 12, height: 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("No scenes yet")
                .font(.headline)
            Text("Create a scene to set multiple blinds with a single tap — \"Morning\", \"Shade\", \"Night\".")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                creating = true
            } label: {
                Label("New scene", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(devices.filter(\.isBlind).isEmpty)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorState(_ err: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(err)
                .font(.callout)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await loadDevices() } }
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadDevices() async {
        loadingDevices = true
        loadError = nil
        do {
            devices = try await client.getDevices()
        } catch {
            loadError = "\(error)"
        }
        loadingDevices = false
    }

    private func run(_ scene: BlindScene) async {
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
}
