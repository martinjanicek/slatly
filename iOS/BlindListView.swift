import SwiftUI
import OverkizKit

struct BlindListView: View {
    let client: OverkizClient

    @State private var devices: [OverkizDevice] = []
    @State private var loadingError: String?
    @State private var isLoading = true
    @State private var renameTarget: OverkizDevice?
    @State private var renameTick: Int = 0

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadingError {
                    errorState(err)
                } else {
                    blindsList
                }
            }
            .navigationTitle("Rooms")
            .refreshable { await load() }
            .sheet(item: $renameTarget) { device in
                RenameBlindSheet(device: device) {
                    renameTick &+= 1
                }
            }
        }
        .task { await load() }
    }

    private var blindsList: some View {
        List {
            Section {
                NavigationLink {
                    BulkTiltView(client: client, devices: devices.filter(\.isBlind))
                } label: {
                    Label {
                        Text("All blinds").fontWeight(.semibold)
                    } icon: {
                        ZStack {
                            Circle().fill(.tint.opacity(0.18))
                            Image(systemName: "rectangle.3.group.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.tint)
                        }
                        .frame(width: 28, height: 28)
                    }
                }
            }
            Section("Individual") {
                ForEach(devices.filter(\.isBlind)) { device in
                    NavigationLink {
                        TiltView(client: client, device: device)
                    } label: {
                        Label {
                            Text(displayName(for: device))
                                .lineLimit(1)
                        } icon: {
                            Circle()
                                .fill(BlindThemeStore.theme(for: device.deviceURL).swatch)
                                .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                                .frame(width: 22, height: 22)
                        }
                    }
                    .id("\(device.deviceURL)-\(renameTick)")
                    .swipeActions(edge: .trailing) {
                        Button {
                            renameTarget = device
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            renameTarget = device
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
            Button("Try again") { Task { await load() } }
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
