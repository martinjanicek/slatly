import SwiftUI

enum BlindTheme: String, CaseIterable, Identifiable {
    case classic
    case white
    case silver
    case anthracite
    case beige
    case brown
    case forest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Modrá"
        case .white: return "Bílá"
        case .silver: return "Stříbrná"
        case .anthracite: return "Antracit"
        case .beige: return "Béžová"
        case .brown: return "Hnědá"
        case .forest: return "Zelená"
        }
    }

    /// Color used as the small swatch in the palette + nav button.
    var swatch: Color {
        switch self {
        case .classic: return Color(red: 0.82, green: 0.85, blue: 0.90)
        case .white: return Color(red: 0.95, green: 0.95, blue: 0.93)
        case .silver: return Color(red: 0.72, green: 0.74, blue: 0.76)
        case .anthracite: return Color(red: 0.22, green: 0.24, blue: 0.26)
        case .beige: return Color(red: 0.82, green: 0.74, blue: 0.58)
        case .brown: return Color(red: 0.40, green: 0.27, blue: 0.16)
        case .forest: return Color(red: 0.18, green: 0.32, blue: 0.20)
        }
    }

    var slatGradient: LinearGradient {
        let (top, bottom): (Color, Color) = {
            switch self {
            case .classic: return (Color(white: 0.92), Color(white: 0.72))
            case .white: return (Color(red: 0.98, green: 0.98, blue: 0.97), Color(red: 0.84, green: 0.84, blue: 0.82))
            case .silver: return (Color(red: 0.84, green: 0.86, blue: 0.88), Color(red: 0.58, green: 0.60, blue: 0.63))
            case .anthracite: return (Color(red: 0.34, green: 0.36, blue: 0.38), Color(red: 0.14, green: 0.16, blue: 0.18))
            case .beige: return (Color(red: 0.90, green: 0.82, blue: 0.68), Color(red: 0.70, green: 0.60, blue: 0.46))
            case .brown: return (Color(red: 0.55, green: 0.38, blue: 0.24), Color(red: 0.28, green: 0.18, blue: 0.10))
            case .forest: return (Color(red: 0.28, green: 0.44, blue: 0.30), Color(red: 0.12, green: 0.24, blue: 0.14))
            }
        }()
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    /// Edge color for slat outline, picked to read against the gradient.
    var slatEdge: Color {
        switch self {
        case .classic, .white, .silver, .beige: return .black.opacity(0.18)
        case .anthracite, .brown, .forest: return .white.opacity(0.10)
        }
    }
}

/// Stores per-device theme choice in UserDefaults.
@MainActor
enum BlindThemeStore {
    static func theme(for deviceURL: String) -> BlindTheme {
        let raw = UserDefaults.standard.string(forKey: storageKey(deviceURL)) ?? BlindTheme.classic.rawValue
        return BlindTheme(rawValue: raw) ?? .classic
    }

    static func set(_ theme: BlindTheme, for deviceURL: String) {
        UserDefaults.standard.set(theme.rawValue, forKey: storageKey(deviceURL))
    }

    private static func storageKey(_ deviceURL: String) -> String { "theme::\(deviceURL)" }
}
