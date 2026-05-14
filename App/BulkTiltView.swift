import SwiftUI
import OverkizKit

/// Marker route used by NavigationStack to push the bulk-control screen.
struct AllBlindsRoute: Hashable {}

/// TiltView for "all blinds at once" — same crown/drag affordances, but every
/// setClosureAndOrientation / my call fans out across all devices in parallel.
struct BulkTiltView: View {
    let client: OverkizClient
    let devices: [OverkizDevice]

    @State private var tilt: Double = 50
    @State private var closure: Double = 50
    @State private var status: Status = .idle
    @State private var sendTask: Task<Void, Never>?
    @State private var dragStartClosure: Double?

    enum Status: Equatable {
        case idle, sending, ok, failed
    }

    var body: some View {
        VStack(spacing: 4) {
            BlindsGraphic(closure: closure, tilt: tilt, theme: .classic)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(closureDrag)
                .animation(.snappy(duration: 0.18), value: closure)
                .animation(.snappy(duration: 0.18), value: tilt)

            HStack(spacing: 0) {
                chip(systemImage: "arrow.up.and.down", value: Int(closure))
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Button { Task { await sendMy() } } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    statusIndicator
                }
                Spacer(minLength: 0)
                chip(systemImage: "rectangle.compress.vertical", value: Int(tilt))
            }
            .frame(height: 18)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .focusable()
        .digitalCrownRotation(
            $tilt,
            from: 0, through: 100, by: 1,
            sensitivity: .high,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: tilt) { _, _ in scheduleSend() }
        .sensoryFeedback(.error, trigger: status == .failed)
        .navigationTitle("Vše (\(devices.count))")
    }

    private var closureDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStartClosure == nil { dragStartClosure = closure }
                let start = dragStartClosure ?? closure
                let delta = value.translation.height * 0.7
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
            Circle().fill(.secondary.opacity(0.3)).frame(width: 6, height: 6)
        case .sending:
            ProgressView().controlSize(.mini)
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption2)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.caption2)
        }
    }

    private func chip(systemImage: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage).font(.system(size: 10, weight: .semibold))
            Text("\(value)").font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
    }

    private func scheduleSend() {
        sendTask?.cancel()
        let c = Int(closure)
        let t = Int(tilt)
        let urls = devices.map(\.deviceURL)
        sendTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
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

    /// Returns `true` if any of the parallel sub-tasks threw.
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
