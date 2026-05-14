import SwiftUI
import OverkizKit

struct BlindListView: View {
    let client: OverkizClient
    let onSignOut: () -> Void

    @State private var devices: [OverkizDevice] = []
    @State private var loadingError: String?
    @State private var isLoading = true
    @State private var showingSignOutConfirm = false

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
        .navigationTitle("Žaluzky")
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
            "Odhlásit se?",
            isPresented: $showingSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Odhlásit", role: .destructive) { onSignOut() }
            Button("Zrušit", role: .cancel) {}
        }
        .task { await load() }
    }

    private var blindsList: some View {
        List {
            Section {
                allControlsRow
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
            }
            Section {
                ForEach(devices.filter(\.isBlind)) { device in
                    NavigationLink(value: device) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(BlindThemeStore.theme(for: device.deviceURL).swatch)
                                .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                                .frame(width: 14, height: 14)
                            Text(device.label ?? device.deviceURL)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: OverkizDevice.self) { device in
            TiltView(client: client, device: device)
        }
    }

    @ViewBuilder
    private func errorState(_ err: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(err)
                .font(.caption2)
                .multilineTextAlignment(.center)
            Button("Zkusit znovu") { Task { await load() } }
                .font(.caption)
            Button("Odhlásit") { onSignOut() }
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }

    private var allControlsRow: some View {
        HStack(spacing: 4) {
            allActionButton(icon: "arrow.up", label: "Otevřít vše") { try await client.open(deviceURL: $0) }
            allActionButton(icon: "stop.fill", label: "Stop vše") { try await client.stop(deviceURL: $0) }
            allActionButton(icon: "arrow.down", label: "Zavřít vše") { try await client.close(deviceURL: $0) }
            allActionButton(icon: "star.fill", label: "My pro vše") { try await client.my(deviceURL: $0) }
        }
    }

    private func allActionButton(
        icon: String,
        label: String,
        action: @escaping @Sendable (String) async throws -> String
    ) -> some View {
        Button {
            let blinds = devices.filter(\.isBlind)
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for d in blinds {
                        let url = d.deviceURL
                        group.addTask { _ = try? await action(url) }
                    }
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
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
            case .badCredentials: return "Špatné heslo"
            case .noAccessToken: return "Token nedostupný"
            case .http(let status, _): return "HTTP \(status)"
            case .decoding: return "Chyba parsování odpovědi"
            case .unexpectedResponse: return "Neočekávaná odpověď"
            }
        }
        return "\(error)"
    }
}
