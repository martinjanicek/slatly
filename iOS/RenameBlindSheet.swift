import SwiftUI
import OverkizKit

/// Small modal sheet for renaming a blind. Shows the current Somfy API label
/// as a hint and lets the user override it; clearing the field restores the
/// API label.
struct RenameBlindSheet: View {
    let device: OverkizDevice
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var focused: Bool

    init(device: OverkizDevice, onSave: @escaping () -> Void) {
        self.device = device
        self.onSave = onSave
        let override = BlindNameStore.name(for: device.deviceURL)
        self._name = State(initialValue: override ?? device.label ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField(device.label ?? "Living room", text: $name)
                        .focused($focused)
                        .submitLabel(.done)
                        .textInputAutocapitalization(.words)
                        .onSubmit { save() }
                }
                if let apiLabel = device.label, !apiLabel.isEmpty {
                    Section {
                        Button {
                            name = ""
                            save()
                        } label: {
                            Label("Reset to Somfy name", systemImage: "arrow.uturn.backward")
                        }
                    } footer: {
                        Text("Somfy name: \(apiLabel)")
                    }
                }
            }
            .navigationTitle("Rename blind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        BlindNameStore.set(trimmed.isEmpty ? nil : trimmed, for: device.deviceURL)
        onSave()
        dismiss()
    }
}
