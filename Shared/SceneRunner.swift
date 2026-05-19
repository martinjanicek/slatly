import Foundation
import OverkizKit

/// Fans out a scene's per-device setpoints in parallel via the Overkiz client.
/// Returns whether any sub-command failed; callers can pair that with their own
/// status indicator.
enum SceneRunner {
    @discardableResult
    static func run(_ scene: BlindScene, client: OverkizClient) async -> Bool {
        let steps = scene.steps
        return await withTaskGroup(of: Bool.self) { group in
            for step in steps {
                let url = step.deviceURL
                let c = step.closure
                let t = step.tilt
                group.addTask {
                    do {
                        _ = try await client.setClosureAndOrientation(deviceURL: url, closure: c, tilt: t)
                        return false
                    } catch {
                        return true
                    }
                }
            }
            var anyFailed = false
            for await failed in group { if failed { anyFailed = true } }
            return anyFailed
        }
    }
}
