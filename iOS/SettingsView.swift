import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: IOSAppState
    @State private var showingSignOutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(.tint.opacity(0.18))
                                .frame(width: 52, height: 52)
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.tint)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signed in").font(.headline)
                            Text(appState.savedUsername.isEmpty ? "—" : appState.savedUsername)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Apple Watch") {
                    InfoRow(icon: "applewatch",
                            title: "Open Slatly on Apple Watch",
                            subtitle: "Credentials arrive via iCloud Keychain, usually within seconds.")
                    InfoRow(icon: "hand.tap.fill",
                            title: "Crown = slats",
                            subtitle: "Rotate the crown to tilt the slats (open or block direct light).")
                    InfoRow(icon: "arrow.up.and.down",
                            title: "Drag = open/close",
                            subtitle: "Drag vertically on the display to set closure 0–100%.")
                    InfoRow(icon: "paintpalette.fill",
                            title: "Blind color",
                            subtitle: "Pick from 7 colors in the top-right of the detail view — saved per blind.")
                }

                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirm = true
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .confirmationDialog(
            "Sign out and remove credentials from Keychain?",
            isPresented: $showingSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { appState.signOut() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
