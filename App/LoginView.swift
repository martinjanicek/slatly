import SwiftUI

struct LoginView: View {
    @ObservedObject var appState: AppState

    @State private var username = ""
    @State private var password = ""
    @State private var signingIn = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Žaluzky")
                    .font(.headline)
                Text("Přihlášení do Somfy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                TextField("E-mail", text: $username)
                    .textContentType(.username)
                    .submitLabel(.next)

                SecureField("Heslo", text: $password)
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
                        Text("Přihlásit")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || signingIn)
                .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
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
            errorMessage = "Špatný email nebo heslo"
        case .failed(let msg):
            errorMessage = msg
        }
    }
}
