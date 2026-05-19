import SwiftUI

/// Renders a stylized exterior venetian blind that responds to closure + tilt:
/// - `closure` (0…100) controls how much of the window is covered (slats coming
///   down from the top).
/// - `tilt` (0…100) controls slat thickness — 0 = thin gaps everywhere
///   (see-through), 100 = slats fully overlap into a solid wall.
struct BlindsGraphic: View {
    let closure: Double
    let tilt: Double
    let theme: BlindTheme

    private let slatCount = 9

    var body: some View {
        GeometryReader { geo in
            let coveredHeight = geo.size.height * CGFloat(closure / 100)
            let slatSlot = max(geo.size.height / CGFloat(slatCount), 1)
            let visibleSlats = max(1, Int(ceil(coveredHeight / slatSlot)))
            let openness = 1 - tilt / 100
            let thickness = slatSlot * (0.12 + 0.88 * (1 - openness))

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.30, green: 0.62, blue: 0.93),
                                Color(red: 0.10, green: 0.30, blue: 0.55),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 0) {
                    ForEach(0..<visibleSlats, id: \.self) { idx in
                        ZStack(alignment: .top) {
                            Color.clear
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(theme.slatGradient)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .stroke(theme.slatEdge, lineWidth: 0.5)
                                )
                                .frame(height: thickness)
                                .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)

                            Rectangle()
                                .fill(.white.opacity(0.4))
                                .frame(height: max(thickness * 0.12, 0.3))
                                .offset(y: 0.2)
                                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                                .frame(height: thickness, alignment: .top)
                        }
                        .frame(height: idx == visibleSlats - 1
                               ? max(coveredHeight - CGFloat(idx) * slatSlot, thickness)
                               : slatSlot,
                               alignment: .top)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 0.7)
            }
        }
    }
}

#Preview("themes") {
    HStack {
        ForEach(BlindTheme.allCases) { t in
            BlindsGraphic(closure: 100, tilt: 50, theme: t)
        }
    }
    .padding()
}
