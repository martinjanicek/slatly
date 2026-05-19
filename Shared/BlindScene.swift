import Foundation

/// User-defined preset that drives N blinds to a specific (closure, tilt) state
/// in parallel. Synced via iCloud Key-Value store so it's available on both
/// the iPhone and Apple Watch.
struct BlindScene: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var iconSystemName: String
    var steps: [Step]

    struct Step: Codable, Hashable {
        var deviceURL: String
        var closure: Int
        var tilt: Int
    }

    init(id: UUID = UUID(), name: String, iconSystemName: String = "sun.max.fill", steps: [Step] = []) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.steps = steps
    }
}
