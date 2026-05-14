import Foundation

public struct OverkizDevice: Sendable, Decodable, Identifiable, Hashable {
    public let deviceURL: String
    public let label: String?
    public let uiClass: String?
    public let widget: String?
    public let states: [DeviceState]?

    public init(
        deviceURL: String,
        label: String?,
        uiClass: String?,
        widget: String?,
        states: [DeviceState]? = nil
    ) {
        self.deviceURL = deviceURL
        self.label = label
        self.uiClass = uiClass
        self.widget = widget
        self.states = states
    }

    public var id: String { deviceURL }

    public func intState(_ name: String) -> Int? {
        states?.first(where: { $0.name == name })?.intValue
    }

    public var currentClosure: Int? { intState("core:ClosureState") }
    public var currentOrientation: Int? { intState("core:SlateOrientationState") }

    /// Whether this device is a blind/shutter/awning we can drive with closure/orientation commands.
    public var isBlind: Bool {
        let known: Set<String> = [
            "RollerShutter",
            "ExteriorScreen",
            "ExteriorVenetianBlind",
            "VenetianBlind",
            "Awning",
            "GarageDoor",
            "Window",
            "Pergola",
            "Screen",
        ]
        return known.contains(uiClass ?? "")
    }

    private enum CodingKeys: String, CodingKey {
        case deviceURL, label, uiClass, widget, states
    }
}

public struct DeviceState: Sendable, Decodable, Hashable {
    public let name: String
    public let intValue: Int?
    public let stringValue: String?

    public init(name: String, intValue: Int? = nil, stringValue: String? = nil) {
        self.name = name
        self.intValue = intValue
        self.stringValue = stringValue
    }

    private enum CodingKeys: String, CodingKey {
        case name, value
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)

        if let i = try? c.decode(Int.self, forKey: .value) {
            self.intValue = i
            self.stringValue = String(i)
        } else if let d = try? c.decode(Double.self, forKey: .value) {
            self.intValue = Int(d)
            self.stringValue = String(d)
        } else if let s = try? c.decode(String.self, forKey: .value) {
            self.intValue = Int(s)
            self.stringValue = s
        } else if let b = try? c.decode(Bool.self, forKey: .value) {
            self.intValue = b ? 1 : 0
            self.stringValue = String(b)
        } else {
            self.intValue = nil
            self.stringValue = nil
        }
    }
}
