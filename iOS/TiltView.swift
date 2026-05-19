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
    @State private var showingRename = false
    @State private var nameOverrideTick: Int = 0
    @State private var myOverrideTick: Int = 0
    @State private var savedMyToast: Bool = false

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
        VStack(spacing: 16) {
            BlindsGraphic(closure: closure, tilt: tilt, theme: theme)
                .frame(maxWidth: 360, maxHeight: 380)
                .contentShape(Rectangle())
                .gesture(closureDrag)
                .animation(.snappy(duration: 0.18), value: closure)
                .animation(.snappy(duration: 0.18), value: tilt)
                .padding(.horizontal)

            VStack(spacing: 12) {
                sliderRow(
                    icon: "arrow.up.and.down",
                    label: "Closure",
                    value: $closure,
                    suffix: "%"
                )
                sliderRow(
                    icon: "rectangle.compress.vertical",
                    label: "Tilt",
                    value: $tilt,
                    suffix: ""
                )
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
        .navigationTitle(Text(displayName(for: device)))
        .navigationBarTitleDisplayMode(.inline)
        .id(nameOverrideTick) // refresh title after rename
        .onChange(of: closure) { _, _ in scheduleSend() }
        .onChange(of: tilt) { _, _ in scheduleSend() }
        .sensoryFeedback(.error, trigger: status == .failed)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        showingPalette = true
                    } label: {
                        Label("Color", systemImage: "paintpalette")
                    }

                    Section("My (★)") {
                        Button {
                            saveMyPosition()
                        } label: {
                            Label("Save current as My", systemImage: "star.fill")
                        }
                        if MyPositionStore.position(for: device.deviceURL) != nil {
                            Button(role: .destructive) {
                                MyPositionStore.clear(for: device.deviceURL)
                                myOverrideTick &+= 1
                            } label: {
                                Label("Reset to device default", systemImage: "star.slash")
                            }
                        }
                    }
                } label: {
                    Circle()
                        .fill(theme.swatch)
                        .overlay(Circle().stroke(.secondary.opacity(0.4), lineWidth: 0.8))
                        .frame(width: 24, height: 24)
                }
            }
        }
        .overlay(alignment: .top) {
            if savedMyToast {
                Text("My position saved")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.green))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingPalette) {
            NavigationStack {
                ColorPaletteView(selection: $theme) { picked in
                    BlindThemeStore.set(picked, for: device.deviceURL)
                }
                .navigationTitle("Blind color")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingRename) {
            RenameBlindSheet(device: device) {
                nameOverrideTick &+= 1
            }
        }
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
                // Custom My override — drive directly to the saved closure + tilt
                _ = try await client.setClosureAndOrientation(
                    deviceURL: device.deviceURL,
                    closure: pos.closure,
                    tilt: pos.tilt
                )
            } else {
                // Use the position registered on the Somfy device itself
                _ = try await client.my(deviceURL: device.deviceURL)
            }
            status = .ok
        } catch {
            status = .failed
        }
    }

    private func saveMyPosition() {
        MyPositionStore.save(
            .init(closure: Int(closure), tilt: Int(tilt)),
            for: device.deviceURL
        )
        myOverrideTick &+= 1
        withAnimation(.snappy) { savedMyToast = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) { savedMyToast = false }
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
