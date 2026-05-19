import SwiftUI
import OverkizKit

struct BulkTiltView: View {
    let client: OverkizClient
    let devices: [OverkizDevice]

    @State private var tilt: Double
    @State private var closure: Double
    @State private var status: Status = .idle
    @State private var sendTask: Task<Void, Never>?
    @State private var dragStartClosure: Double?

    init(client: OverkizClient, devices: [OverkizDevice]) {
        self.client = client
        self.devices = devices
        let closures = devices.compactMap(\.currentClosure)
        let tilts = devices.compactMap(\.currentOrientation)
        let avgClosure = closures.isEmpty ? 50.0 : Double(closures.reduce(0, +)) / Double(closures.count)
        let avgTilt = tilts.isEmpty ? 50.0 : Double(tilts.reduce(0, +)) / Double(tilts.count)
        self._closure = State(initialValue: avgClosure)
        self._tilt = State(initialValue: avgTilt)
    }

    enum Status: Equatable {
        case idle, sending, ok, failed
    }

    var body: some View {
        VStack(spacing: 16) {
            BlindsGraphic(closure: closure, tilt: tilt, theme: .classic)
                .frame(maxWidth: 360, maxHeight: 380)
                .contentShape(Rectangle())
                .gesture(closureDrag)
                .animation(.snappy(duration: 0.18), value: closure)
                .animation(.snappy(duration: 0.18), value: tilt)
                .padding(.horizontal)

            VStack(spacing: 12) {
                sliderRow(icon: "arrow.up.and.down", label: "Closure", value: $closure, suffix: "%")
                sliderRow(icon: "rectangle.compress.vertical", label: "Tilt", value: $tilt, suffix: "")
            }
            .padding(.horizontal)

            HStack(spacing: 14) {
                Button {
                    Task { await sendMy() }
                } label: {
                    Label("My", systemImage: "star.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await sendStop() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                statusIndicator
                    .frame(width: 24)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle(Text("All (\(devices.count))"))
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(spacing: 4) {
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

    private var closureDrag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragStartClosure == nil { dragStartClosure = closure }
                let start = dragStartClosure ?? closure
                let delta = value.translation.height * 0.35
                closure = max(0, min(100, start + delta))
            }
            .onEnded { _ in
                dragStartClosure = nil
                scheduleSend()
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
        let urls = devices.map(\.deviceURL)
        sendTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            status = .sending
            let anyFailed = await fanOut(urls: urls) { url in
                _ = try await client.setClosureAndOrientation(deviceURL: url, closure: c, tilt: t)
            }
            status = anyFailed ? .failed : .ok
        }
    }

    private func sendMy() async {
        sendTask?.cancel()
        status = .sending
        let urls = devices.map(\.deviceURL)
        let anyFailed = await fanOut(urls: urls) { url in
            _ = try await client.my(deviceURL: url)
        }
        status = anyFailed ? .failed : .ok
    }

    private func sendStop() async {
        sendTask?.cancel()
        status = .sending
        let urls = devices.map(\.deviceURL)
        let anyFailed = await fanOut(urls: urls) { url in
            _ = try await client.stop(deviceURL: url)
        }
        status = anyFailed ? .failed : .ok
    }

    private func fanOut(
        urls: [String],
        _ action: @escaping @Sendable (String) async throws -> Void
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            for url in urls {
                group.addTask {
                    do { try await action(url); return false }
                    catch { return true }
                }
            }
            var anyFailed = false
            for await failed in group { if failed { anyFailed = true } }
            return anyFailed
        }
    }
}
