import SwiftUI
import OverkizKit

struct TiltView: View {
    let client: OverkizClient
    let device: OverkizDevice

    @State private var tilt: Double
    @State private var closure: Double
    @State private var status: Status = .idle
    @State private var sendTask: Task<Void, Never>?
    @State private var dragStartClosure: Double?
    @State private var theme: BlindTheme
    @State private var showingPalette = false

    init(client: OverkizClient, device: OverkizDevice) {
        self.client = client
        self.device = device
        self._theme = State(initialValue: BlindThemeStore.theme(for: device.deviceURL))
        self._closure = State(initialValue: Double(device.currentClosure ?? 100))
        self._tilt = State(initialValue: Double(device.currentOrientation ?? 50))
    }

    enum Status: Equatable {
        case idle, sending, ok, failed
    }

    var body: some View {
        VStack(spacing: 4) {
            BlindsGraphic(closure: closure, tilt: tilt, theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(closureDrag)
                .animation(.snappy(duration: 0.18), value: closure)
                .animation(.snappy(duration: 0.18), value: tilt)

            HStack(spacing: 0) {
                ValueChip(systemImage: "arrow.up.and.down", value: Int(closure))
                Spacer(minLength: 0)
                statusIndicator
                Spacer(minLength: 0)
                ValueChip(systemImage: "rectangle.compress.vertical", value: Int(tilt))
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
        .navigationTitle(device.label ?? "?")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingPalette = true
                } label: {
                    Circle()
                        .fill(theme.swatch)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.6))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingPalette) {
            ColorPaletteView(selection: $theme) { picked in
                BlindThemeStore.set(picked, for: device.deviceURL)
            }
        }
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

    private func scheduleSend() {
        sendTask?.cancel()
        let c = Int(closure)
        let t = Int(tilt)
        sendTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
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
}

private struct ValueChip: View {
    let systemImage: String
    let value: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage).font(.system(size: 10, weight: .semibold))
            Text("\(value)").font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
    }
}
