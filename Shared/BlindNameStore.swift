import Foundation
import OverkizKit

/// Per-device user-defined name override, stored in UserDefaults.
/// Falls back to the label coming from the Somfy API if no override is set.
@MainActor
enum BlindNameStore {
    /// Returns user override or nil.
    static func name(for deviceURL: String) -> String? {
        let v = UserDefaults.standard.string(forKey: storageKey(deviceURL))
        return (v?.isEmpty == false) ? v : nil
    }

    /// Pass nil or empty string to clear the override.
    static func set(_ name: String?, for deviceURL: String) {
        let key = storageKey(deviceURL)
        if let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmed.isEmpty {
            UserDefaults.standard.set(trimmed, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func storageKey(_ deviceURL: String) -> String { "name::\(deviceURL)" }
}

/// Resolves the best label for a device: user override → Somfy API label →
/// raw deviceURL.
@MainActor
func displayName(for device: OverkizDevice) -> String {
    BlindNameStore.name(for: device.deviceURL) ?? device.label ?? device.deviceURL
}
