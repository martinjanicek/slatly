import Foundation

/// Per-device override for the "My" button. If a position is saved, tapping My
/// sends `setClosureAndOrientation` with those values; otherwise the app falls
/// back to Somfy's built-in `my` command (which uses whatever position is
/// registered on the device itself).
///
/// Stored locally in UserDefaults — intentionally not iCloud-synced so each
/// user can have their own My preference per device.
@MainActor
enum MyPositionStore {
    struct Position: Codable, Equatable, Sendable {
        let closure: Int
        let tilt: Int
    }

    static func position(for deviceURL: String) -> Position? {
        guard let data = UserDefaults.standard.data(forKey: storageKey(deviceURL)) else { return nil }
        return try? JSONDecoder().decode(Position.self, from: data)
    }

    static func save(_ position: Position, for deviceURL: String) {
        guard let data = try? JSONEncoder().encode(position) else { return }
        UserDefaults.standard.set(data, forKey: storageKey(deviceURL))
    }

    static func clear(for deviceURL: String) {
        UserDefaults.standard.removeObject(forKey: storageKey(deviceURL))
    }

    private static func storageKey(_ deviceURL: String) -> String { "myposition::\(deviceURL)" }
}
