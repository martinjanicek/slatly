import SwiftUI
import OverkizKit

/// Single-screen view of every blind with inline closure + tilt sliders, plus
/// per-blind My / Stop buttons. No drilling into a detail screen needed for the
/// common case of nudging several rooms quickly.
struct DashboardView: View {
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
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadingError {
                    errorState(err)
                } else {
                    dashboard
                }
            }
            .navigationTitle("Dashboard")
            .refreshable { await load() }
            .sheet(item: $renameTarget) { device in
                RenameBlindSheet(device: device) {
                    renameTick &+= 1
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var dashboard: some View {
        let blinds = devices.filter(\.isBlind)
        if blinds.isEmpty {
            ContentUnavailableView(
                "No blinds found",
                systemImage: "blinds.horizontal.closed",
                description: Text("Your Somfy account has no exterior venetian blinds attached to it.")
            )
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(blinds) { device in
                        BlindControlRow(client: client, device: device)
                            .id("\(device.deviceURL)-\(renameTick)")
                            .contextMenu {
                                Button {
                                    renameTarget = device
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
        }
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
            loadingError = "\(error)"
        }
        isLoading = false
    }
}

/// One row per blind. Holds its own state and debounces the network commit so
/// dragging both sliders only fires a single `setClosureAndOrientation`.
private struct BlindControlRow: View {
    let client: OverkizClient
    let device: OverkizDevice

    @State private var closure: Double
    @State private var tilt: Double
    @State private var status: Status = .idle
    @State private var sendTask: Task<Void, Never>?
    @State private var theme: BlindTheme

    init(client: OverkizClient, device: OverkizDevice) {
        self.client = client
        self.device = device
        self._closure = State(initialValue: Double(device.currentClosure ?? 100))
        self._tilt = State(initialValue: Double(device.currentOrientation ?? 50))
        self._theme = State(initialValue: BlindThemeStore.theme(for: device.deviceURL))
    }

    enum Status: Equatable { case idle, sending, ok, failed }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(theme.swatch)
                    .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                    .frame(width: 24, height: 24)
                Text(displayName(for: device))
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                statusIndicator
                Button {
                    Task { await sendMy() }
                } label: {
                    Image(systemName: "star.fill")
                        .frame(width: 30, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    Task { await sendStop() }
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 30, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }

            sliderRow(icon: "arrow.up.and.down", label: "Closure", value: $closure, suffix: "%")
            sliderRow(icon: "rectangle.compress.vertical", label: "Tilt", value: $tilt, suffix: "")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onChange(of: closure) { _, _ in scheduleSend() }
        .onChange(of: tilt) { _, _ in scheduleSend() }
        .sensoryFeedback(.error, trigger: status == .failed)
    }

    private func sliderRow(
        icon: String,
        label: LocalizedStringKey,
        value: Binding<Double>,
        suffix: String
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(value.wrappedValue))\(suffix)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...100, step: 1)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .idle:
            Circle().fill(.secondary.opacity(0.3)).frame(width: 8, height: 8)
        case .sending:
            ProgressView().controlSize(.small)
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private func scheduleSend() {
        sendTask?.cancel()
        let c = Int(closure)
        let t = Int(tilt)
        sendTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            status = .sending
            do {
                _ = try await client.setClosureAndOrientation(deviceURL: device.deviceURL, closure: c, tilt: t)
                status = .ok
            } catch {
                status = .failed
            }
        }
    }

    private func sendMy() async {
        sendTask?.cancel()
        status = .sending
        do {
            if let pos = MyPositionStore.position(for: device.deviceURL) {
                _ = try await client.setClosureAndOrientation(
                    deviceURL: device.deviceURL,
                    closure: pos.closure,
                    tilt: pos.tilt
                )
            } else {
                _ = try await client.my(deviceURL: device.deviceURL)
            }
            status = .ok
        } catch {
            status = .failed
        }
    }

    private func sendStop() async {
        sendTask?.cancel()
        status = .sending
        do {
            _ = try await client.stop(deviceURL: device.deviceURL)
            status = .ok
        } catch {
            status = .failed
        }
    }
}
