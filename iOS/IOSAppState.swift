import Foundation
import OverkizKit

@MainActor
final class IOSAppState: ObservableObject {
    @Published private(set) var client: OverkizClient?
    @Published private(set) var savedUsername: String

    init() {
        if let creds = CredentialsStore.load() {
            self.savedUsername = creds.username
            self.client = OverkizClient(credentials: .init(username: creds.username, password: creds.password))
        } else {
            self.savedUsername = ""
            self.client = nil
        }
    }

    var isSignedIn: Bool { client != nil }

    func signIn(username: String, password: String) async -> Result<Void, SignInError> {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = OverkizClient(
            credentials: .init(username: trimmed, password: password)
        )
        do {
            _ = try await candidate.getDevices()
        } catch OverkizError.badCredentials {
            return .failure(.badCredentials)
        } catch {
            return .failure(.other("\(error)"))
        }
        CredentialsStore.save(.init(username: trimmed, password: password))
        self.savedUsername = trimmed
        self.client = candidate
        return .success(())
    }

    func signOut() {
        CredentialsStore.clear()
        self.savedUsername = ""
        self.client = nil
    }

    enum SignInError: Error, Equatable {
        case badCredentials
        case other(String)
    }
}
