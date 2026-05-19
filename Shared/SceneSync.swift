import Foundation
import WatchConnectivity

/// Pushes the scene list across a paired iPhone ↔ Apple Watch using
/// `WCSession.updateApplicationContext`. This is the immediate sync path; the
/// iCloud Keychain mirror in `SceneStore` handles longer-term cross-device
/// persistence and recovers on a fresh install.
///
/// Activation is best-effort: if the user doesn't have a paired Watch (or in
/// a single-platform simulator where WCSession isn't paired), nothing happens
/// and the keychain sync path still runs.
final class SceneSync: NSObject, @unchecked Sendable {
    static let shared = SceneSync()

    private nonisolated static let payloadKey = "scenes.v1"

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Push the latest scene snapshot to the other device. Uses
    /// `updateApplicationContext` which overwrites the previous context — so we
    /// always send the full list, not deltas, and ordering / deletions are
    /// preserved.
    func push(_ scenes: [BlindScene]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(scenes) else { return }
        try? session.updateApplicationContext([Self.payloadKey: data])
    }
}

extension SceneSync: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Extract Data here (Sendable) before crossing isolation.
        let data = session.receivedApplicationContext[Self.payloadKey] as? Data
        if let data {
            Task { @MainActor in
                SceneStore.shared.ingestRemote(data)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let data = applicationContext[Self.payloadKey] as? Data
        if let data {
            Task { @MainActor in
                SceneStore.shared.ingestRemote(data)
            }
        }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Apple recommends reactivating after deactivation (e.g. switching to
        // a new paired Apple Watch).
        WCSession.default.activate()
    }
#endif
}
