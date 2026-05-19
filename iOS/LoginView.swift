import SwiftUI

struct LoginView: View {
    @ObservedObject var appState: IOSAppState

    @State private var username = ""
    @State private var password = ""
    @State private var signingIn = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field { case username, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 24)

                Image(systemName: "blinds.horizontal.closed")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(.tint)

                VStack(spacing: 4) {
                    Text("Slatly")
                        .font(.largeTitle.bold())
                    Text("Sign in to Somfy / TaHoma")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email").font(.caption).foregroundStyle(.secondary)
                        TextField("you@example.com", text: $username)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password").font(.caption).foregroundStyle(.secondary)
                        SecureField("•••••••", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await submit() } }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if signingIn {
                        ProgressView().controlSize(.regular).tint(.white)
                    } else {
                        Text("Sign in")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(username.isEmpty || password.isEmpty || signingIn)

                Text("After signing in, credentials are saved to iCloud Keychain and synced to your Apple Watch (even without an iPhone nearby).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 24)
        }
    }

    private func submit() async {
        guard !signingIn else { return }
        signingIn = true
        errorMessage = nil
        let result = await appState.signIn(username: username, password: password)
        signingIn = false
        if case .failure(let err) = result {
            switch err {
            case .badCredentials: errorMessage = String(localized: "Wrong email or password")
            case .other(let msg): errorMessage = msg
            }
        }
    }
}
