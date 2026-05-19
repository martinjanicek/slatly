import Foundation
import Combine
import Security

/// iCloud-synced storage for `BlindScene` presets.
///
/// Persists the scene list as a JSON blob in the iCloud Keychain
/// (`kSecAttrSynchronizable = true`), which is the same mechanism the app
/// already uses for Somfy credentials. This works on iPhone + Apple Watch
/// without requiring an additional iCloud entitlement in the developer portal —
/// as long as the user has iCloud Keychain enabled, scenes created on the
/// phone show up on the watch within seconds.
///
/// Limits to be aware of: keychain items synced via iCloud are capped at
/// ~4 KB. With (closure, tilt, deviceURL) per blind that comfortably fits
/// dozens of scenes across dozens of blinds.
@MainActor
final class SceneStore: ObservableObject {
    static let shared = SceneStore()

    @Published private(set) var scenes: [BlindScene] = []

    private let service = "com.punkhive.zaluzky"
    private let account = "scenes.v1"

    private init() {
        refresh()
    }

    /// Re-read keychain. Call from `.task` / `.onAppear` to pick up scenes
    /// that were created on the other device and synced via iCloud.
    func refresh() {
        guard let data = loadItem(),
              let decoded = try? JSONDecoder().decode([BlindScene].self, from: data) else { return }
        if decoded != scenes {
            scenes = decoded
        }
    }

    func upsert(_ scene: BlindScene) {
        if let idx = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[idx] = scene
        } else {
            scenes.append(scene)
        }
        persist()
    }

    func delete(_ scene: BlindScene) {
        scenes.removeAll { $0.id == scene.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        scenes.remove(atOffsets: offsets)
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        scenes.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    /// Called by `SceneSync` when the paired device pushes a fresh scene list
    /// via WatchConnectivity. Writes locally and skips the sync push to avoid
    /// echoing the change back.
    func ingestRemote(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode([BlindScene].self, from: data) else { return }
        guard decoded != scenes else { return }
        scenes = decoded
        // Persist locally (keychain mirror) but don't re-broadcast.
        saveItem(data)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(scenes) else { return }
        saveItem(data)
        SceneSync.shared.push(scenes)
    }

    // MARK: - Keychain helpers (mirrors CredentialsStore)

    private func saveItem(_ value: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = value
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadItem() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }
}
