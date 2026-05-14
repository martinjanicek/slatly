import SwiftUI

struct SignedInView: View {
    @ObservedObject var appState: IOSAppState
    @State private var showingSignOutConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 24)

                ZStack {
                    Circle()
                        .fill(.tint.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                }

                VStack(spacing: 4) {
                    Text("Přihlášeno")
                        .font(.title.bold())
                    Text(appState.savedUsername)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    InfoRow(icon: "applewatch", title: "Otevři Žaluzky na Apple Watch", subtitle: "Přihlášení dorazí přes iCloud Klíčenku, obvykle do několika vteřin.")
                    InfoRow(icon: "hand.tap.fill", title: "Korunka = lamely", subtitle: "Točením korunky naklápíš lamely (otevřeš/zavřeš proud světla).")
                    InfoRow(icon: "arrow.up.and.down", title: "Drag = výjezd/sjezd", subtitle: "Tahem prstu po displeji ovládáš closure 0–100 %.")
                    InfoRow(icon: "paintpalette.fill", title: "Barva žaluzie", subtitle: "V detailu vpravo nahoře vybereš jednu ze 7 barev — uloží se per žaluzii.")
                }

                Divider()

                Button(role: .destructive) {
                    showingSignOutConfirm = true
                } label: {
                    Label("Odhlásit", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text("Tuto aplikaci na iPhonu nepotřebuješ k běžnému ovládání — klidně ji smaž po nastavení.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 24)
        }
        .confirmationDialog(
            "Odhlásit a smazat přihlašovací údaje z Klíčenky?",
            isPresented: $showingSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Odhlásit", role: .destructive) { appState.signOut() }
            Button("Zrušit", role: .cancel) {}
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let subtitle: String

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
    }
}
