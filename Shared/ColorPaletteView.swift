import SwiftUI

struct ColorPaletteView: View {
    @Binding var selection: BlindTheme
    let onPick: (BlindTheme) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 36), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Blind color")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(BlindTheme.allCases) { theme in
                        Button {
                            selection = theme
                            onPick(theme)
                            dismiss()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(theme.swatch)
                                    .frame(width: 34, height: 34)
                                Circle()
                                    .stroke(
                                        selection == theme ? Color.accentColor : Color.white.opacity(0.25),
                                        lineWidth: selection == theme ? 2.5 : 0.6
                                    )
                                    .frame(width: 34, height: 34)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }
}
