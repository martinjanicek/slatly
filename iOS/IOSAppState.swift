import Foundation
import OverkizKit

@MainActor
final class IOSAppState: ObservableObject {
    @Published var isSignedIn: Bool = CredentialsStore.load() != nil
    @Published var savedUsername: String = CredentialsStore.load()?.username ?? ""

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
        self.isSignedIn = true
        return .success(())
    }

    func signOut() {
        CredentialsStore.clear()
        self.savedUsername = ""
        self.isSignedIn = false
    }

    enum SignInError: Error, Equatable {
        case badCredentials
        case other(String)
    }
}
