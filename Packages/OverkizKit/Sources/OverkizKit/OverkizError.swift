import Foundation

public enum OverkizError: Error, Sendable, Equatable {
    case badCredentials
    case noAccessToken
    case http(status: Int, body: String)
    case decoding(String)
    case unexpectedResponse(String)
}
