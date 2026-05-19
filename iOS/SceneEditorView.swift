import SwiftUI
import OverkizKit

/// Edit (or create) a `BlindScene`: name, icon, and per-device (closure, tilt)
/// setpoints. Devices not included in the scene are simply not commanded when
/// it runs.
struct SceneEditorView: View {
    let devices: [OverkizDevice]
    let existing: BlindScene?
    let onSave: (BlindScene) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var iconSystemName: String
    /// deviceURL → (included, closure, tilt). `included == false` means the
    /// scene does not touch that blind.
    @State private var perDevice: [String: DeviceConfig] = [:]

    struct DeviceConfig: Equatable {
        var included: Bool
        var closure: Double
        var tilt: Double
    }

    init(devices: [OverkizDevice], existing: BlindScene?, onSave: @escaping (BlindScene) -> Void) {
        self.devices = devices
        self.existing = existing
        self.onSave = onSave
        if let existing {
            self._name = State(initialValue: existing.name)
            self._iconSystemName = State(initialValue: existing.iconSystemName)
        } else {
            self._name = State(initialValue: "")
            self._iconSystemName = State(initialValue: "sun.max.fill")
        }
    }

    private static let iconChoices = [
        "sun.max.fill", "sun.horizon.fill", "sunrise.fill", "sunset.fill",
        "moon.fill", "moon.stars.fill", "cloud.fill", "sparkles",
        "bed.double.fill", "house.fill", "person.fill", "leaf.fill",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Morning, Shade, Night…", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.iconChoices, id: \.self) { name in
                                Button {
                                    iconSystemName = name
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(name == iconSystemName ? Color.accentColor : Color.secondary.opacity(0.15))
                                            .frame(width: 42, height: 42)
                                        Image(systemName: name)
                                            .font(.system(size: 18))
                                            .foregroundStyle(name == iconSystemName ? .white : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                ForEach(devices) { device in
                    deviceSection(for: device)
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) {
                            if let existing { SceneStore.shared.delete(existing) }
                            dismiss()
                        } label: {
                            Label("Delete scene", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New scene" : "Edit scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { seedDevices() }
    }

    @ViewBuilder
    private func deviceSection(for device: OverkizDevice) -> some View {
        let cfg = perDevice[device.deviceURL] ?? .init(included: false, closure: 100, tilt: 50)
        Section {
            Toggle(isOn: Binding(
                get: { cfg.included },
                set: { newValue in
                    var c = perDevice[device.deviceURL] ?? .init(included: false, closure: 100, tilt: 50)
                    c.included = newValue
                    perDevice[device.deviceURL] = c
                }
            )) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(BlindThemeStore.theme(for: device.deviceURL).swatch)
                        .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                        .frame(width: 22, height: 22)
                    Text(displayName(for: device))
                }
            }

            if cfg.included {
                slider(label: "Closure", suffix: "%", value: Binding(
                    get: { cfg.closure },
                    set: { newValue in
                        var c = perDevice[device.deviceURL] ?? .init(included: true, closure: 100, tilt: 50)
                        c.closure = newValue
                        perDevice[device.deviceURL] = c
                    }
                ))
                slider(label: "Tilt", suffix: "", value: Binding(
                    get: { cfg.tilt },
                    set: { newValue in
                        var c = perDevice[device.deviceURL] ?? .init(included: true, closure: 100, tilt: 50)
                        c.tilt = newValue
                        perDevice[device.deviceURL] = c
                    }
                ))
            }
        }
    }

    private func slider(label: LocalizedStringKey, suffix: String, value: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(value.wrappedValue))\(suffix)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...100, step: 1)
        }
    }

    private func seedDevices() {
        guard perDevice.isEmpty else { return }
        let existingSteps = Dictionary(uniqueKeysWithValues: (existing?.steps ?? []).map { ($0.deviceURL, $0) })
        for d in devices {
            if let step = existingSteps[d.deviceURL] {
                perDevice[d.deviceURL] = .init(included: true, closure: Double(step.closure), tilt: Double(step.tilt))
            } else {
                perDevice[d.deviceURL] = .init(
                    included: false,
                    closure: Double(d.currentClosure ?? 100),
                    tilt: Double(d.currentOrientation ?? 50)
                )
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let steps: [BlindScene.Step] = devices.compactMap { device in
            guard let cfg = perDevice[device.deviceURL], cfg.included else { return nil }
            return .init(deviceURL: device.deviceURL, closure: Int(cfg.closure), tilt: Int(cfg.tilt))
        }
        let scene = BlindScene(
            id: existing?.id ?? UUID(),
            name: trimmed,
            iconSystemName: iconSystemName,
            steps: steps
        )
        onSave(scene)
        dismiss()
    }
}
