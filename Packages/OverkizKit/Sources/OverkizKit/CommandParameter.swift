import Foundation

public enum CommandParameter: Sendable, Encodable, Equatable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        }
    }
}

extension CommandParameter: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}

extension CommandParameter: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}

extension CommandParameter: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension CommandParameter: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}
