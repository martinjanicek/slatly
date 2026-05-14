import Foundation
import OverkizKit

@MainActor
final class AppState: ObservableObject {
    @Published var client: OverkizClient?

    init() {
        refreshFromKeychain()
        if client == nil, let migrated = migrateFromSecrets() {
            CredentialsStore.save(migrated)
            self.client = OverkizClient(
                credentials: .init(username: migrated.username, password: migrated.password)
            )
        }
    }

    /// Re-read Keychain. Useful when scene becomes active and credentials may have
    /// arrived via iCloud Keychain sync from the iOS companion.
    func refreshFromKeychain() {
        if let creds = CredentialsStore.load() {
            if let current = client {
                Task { @MainActor in
                    // No-op if creds unchanged; client doesn't expose its creds, so
                    // we just leave it — if creds match they keep working.
                    _ = current
                }
            } else {
                self.client = OverkizClient(
                    credentials: .init(username: creds.username, password: creds.password)
                )
            }
        }
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

    private func migrateFromSecrets() -> CredentialsStore.Credentials? {
        let user = Secrets.somfyUsername
        let pw = Secrets.somfyPassword
        guard !user.isEmpty, user != "you@example.com",
              !pw.isEmpty, pw != "your-password" else {
            return nil
        }
        return .init(username: user, password: pw)
    }
}
