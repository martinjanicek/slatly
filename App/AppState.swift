import Foundation
import OverkizKit

@MainActor
final class AppState: ObservableObject {
    @Published var client: OverkizClient?

    init() {
        refreshFromKeychain()
    }

    /// Re-read Keychain. Useful when scene becomes active and credentials may have
    /// arrived via iCloud Keychain sync from the iOS companion.
    func refreshFromKeychain() {
        guard client == nil, let creds = CredentialsStore.load() else { return }
        self.client = OverkizClient(
            credentials: .init(username: creds.username, password: creds.password)
        )
    }

    enum SignInResult: Equatable {
        case ok
        case badCredentials
        case failed(String)
    }

    func signIn(username: String, password: String) async -> SignInResult {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = OverkizClient(
            credentials: .init(username: trimmedUser, password: password)
        )
        do {
            _ = try await candidate.getDevices()
        } catch OverkizError.badCredentials {
            return .badCredentials
        } catch {
            return .failed("\(error)")
        }
        CredentialsStore.save(.init(username: trimmedUser, password: password))
        self.client = candidate
        return .ok
    }

    func signOut() {
        CredentialsStore.clear()
        self.client = nil
    }
}
