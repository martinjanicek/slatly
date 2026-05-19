import SwiftUI

/// Watch shows a wait-for-iPhone hint by default — typing a password on a 40 mm
/// screen is misery. The manual fallback is hidden behind a disclosure so users
/// without a paired iPhone (or who want to type anyway) can still sign in.
struct LoginView: View {
    @ObservedObject var appState: AppState

    @State private var showingManual = false
    @State private var username = ""
    @State private var password = ""
    @State private var signingIn = false
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Slatly")
                    .font(.headline)
                Text("Open Slatly on your iPhone to sign in.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 2)
                Text("Waiting for iCloud Keychain…")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Button {
                    showingManual.toggle()
                } label: {
                    Text(showingManual ? "Hide manual sign-in" : "Sign in here instead")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .padding(.top, 6)

                if showingManual {
                    manualForm
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 6)
        }
        .task {
            pollTask?.cancel()
            pollTask = Task { @MainActor in
                while !Task.isCancelled, appState.client == nil {
                    try? await Task.sleep(for: .seconds(2))
                    appState.refreshFromKeychain()
                }
            }
        }
        .onDisappear { pollTask?.cancel() }
    }

    @ViewBuilder
    private var manualForm: some View {
        TextField("Email", text: $username)
            .textContentType(.username)
            .submitLabel(.next)

        SecureField("Password", text: $password)
            .textContentType(.password)
            .submitLabel(.go)

        if let errorMessage {
            Text(errorMessage)
                .font(.caption2)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }

        Button {
            Task { await submit() }
        } label: {
            if signingIn {
                ProgressView().controlSize(.mini)
            } else {
                Text("Sign in")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(username.isEmpty || password.isEmpty || signingIn)
        .padding(.top, 4)
    }

    private func submit() async {
        signingIn = true
        errorMessage = nil
        let result = await appState.signIn(username: username, password: password)
        signingIn = false
        switch result {
        case .ok:
            break
        case .badCredentials:
            errorMessage = "Wrong email or password"
        case .failed(let msg):
            errorMessage = msg
        }
    }
}
