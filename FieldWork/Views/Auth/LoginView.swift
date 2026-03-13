import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var showEmailLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo / Brand
            VStack(spacing: 8) {
                Image(systemName: "ruler.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("FieldWork")
                    .font(.largeTitle.bold())

                Text("Template Technician")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 16) {
                // Apple Sign-In
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)

                // Email fallback
                Button {
                    showEmailLogin.toggle()
                } label: {
                    Text("Sign in with email")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if showEmailLogin {
                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Task { await signInWithEmail() }
                        } label: {
                            if isSigningIn {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            } else {
                                Text("Sign In")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(email.isEmpty || password.isEmpty || isSigningIn)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .animation(.default, value: showEmailLogin)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            Task {
                isSigningIn = true
                do {
                    let authId = try await appState.authManager.signInWithApple(credential: credential)
                    await appState.signIn(authProviderId: authId)
                } catch {
                    self.error = error.localizedDescription
                }
                isSigningIn = false
            }
        case .failure(let err):
            // User cancelled or other Apple Sign-In error
            if (err as NSError).code != ASAuthorizationError.canceled.rawValue {
                error = err.localizedDescription
            }
        }
    }

    private func signInWithEmail() async {
        isSigningIn = true
        error = nil
        do {
            let authId = try await appState.authManager.signInWithEmail(email: email, password: password)
            await appState.signIn(authProviderId: authId)
        } catch {
            self.error = error.localizedDescription
        }
        isSigningIn = false
    }
}
