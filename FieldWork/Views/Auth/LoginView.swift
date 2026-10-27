import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var error: String?
    @State private var revealed = false
    /// Set when Clerk wants a code after the password; the fields swap to the code step.
    @State private var codePrompt: AuthManager.CodePrompt?
    @State private var code = ""
    @FocusState private var focusedField: Field?
    @Environment(\.sfBrandNamespace) private var brandNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo / Brand
            VStack(spacing: 8) {
                SliceMark()
                    .frame(width: SFLaunchView.markSize, height: SFLaunchView.markSize)
                    .sfHeroMarkShadow()
                    .sfBrandMark(brandNamespace)
                    .padding(.bottom, 20)

                Text("FieldWork")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.sfInk)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed || reduceMotion ? 0 : 6)
            }

            Spacer()

            VStack(spacing: 12) {
                if let codePrompt {
                    codeStep(codePrompt)
                } else {
                    passwordStep
                }

                #if DEBUG
                Button("Open demo") {
                    appState.startDemo()
                }
                .font(.footnote)
                .foregroundStyle(Color.sfInkMuted)
                #endif

                if let error = error ?? appState.signInError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.sfDanger)
                        .multilineTextAlignment(.center)
                }

                // Keeps its space so nothing jumps, but fades while the keyboard would clip it.
                SFLogoLockup(markSize: 16)
                    .padding(.top, 16)
                    .opacity(focusedField == nil ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: focusedField)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed || reduceMotion ? 0 : 12)
        }
        .background(Color.sfSurface100.ignoresSafeArea())
        .onAppear {
            // Title and form follow the mark in once it has settled.
            withAnimation(.easeOut(duration: 0.35).delay(0.2)) {
                revealed = true
            }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var passwordStep: some View {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .modifier(SFFieldStyle(isFocused: focusedField == .email))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        guard !email.isEmpty, !password.isEmpty, !isSigningIn else { return }
                        Task { await signInWithEmail() }
                    }
                    .modifier(SFFieldStyle(isFocused: focusedField == .password))

                Button {
                    Task { await signInWithEmail() }
                } label: {
                    Group {
                        if isSigningIn {
                            ProgressView()
                                .tint(Color.sfSurface200)
                        } else {
                            Text("Sign in")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(SFPrimaryButtonStyle())
                .disabled(email.isEmpty || password.isEmpty || isSigningIn)
                .padding(.top, 4)
    }

    /// Clerk asked for a code after the password (new device, or two-step verification).
    @ViewBuilder
    private func codeStep(_ prompt: AuthManager.CodePrompt) -> some View {
        Text(prompt.message)
            .font(.subheadline)
            .foregroundStyle(Color.sfInk)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)

        TextField("Code", text: $code)
            .textContentType(.oneTimeCode)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: .code)
            .modifier(SFFieldStyle(isFocused: focusedField == .code))

        Button {
            Task { await verifyCode(prompt) }
        } label: {
            Group {
                if isSigningIn {
                    ProgressView()
                        .tint(Color.sfSurface200)
                } else {
                    Text("Verify")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(SFPrimaryButtonStyle())
        .disabled(code.isEmpty || isSigningIn)
        .padding(.top, 4)

        Button("Use a different login") {
            codePrompt = nil
            code = ""
            error = nil
        }
        .font(.footnote)
        .foregroundStyle(Color.sfInkMuted)
    }

    private enum Field {
        case email, password, code
    }

    private func signInWithEmail() async {
        isSigningIn = true
        error = nil
        NSLog("[FieldWork] Attempting email sign-in for: %@", email)
        do {
            let step = try await appState.authManager.signInWithEmail(email: email, password: password)
            await finish(step)
        } catch {
            NSLog("[FieldWork] Sign-in error: %@", "\(error)")
            self.error = error.localizedDescription
        }
        isSigningIn = false
    }

    private func verifyCode(_ prompt: AuthManager.CodePrompt) async {
        isSigningIn = true
        error = nil
        do {
            let step = try await appState.authManager.verifyCode(code, for: prompt)
            await finish(step)
        } catch {
            NSLog("[FieldWork] Code error: %@", "\(error)")
            self.error = error.localizedDescription
        }
        isSigningIn = false
    }

    private func finish(_ step: AuthManager.SignInStep) async {
        switch step {
        case .signedIn(let clerkUserId):
            NSLog("[FieldWork] Signed in to Clerk: %@", clerkUserId)
            codePrompt = nil
            await appState.signIn(clerkUserId: clerkUserId, email: email)
        case .needsCode(let prompt):
            NSLog("[FieldWork] Clerk wants a code (%@)", "\(prompt.type)")
            code = ""
            codePrompt = prompt
            focusedField = .code
        }
    }
}

/// Text field on the login screen: surface-200 fill, border-strong outline, radius-md.
/// The focused field gets the brand focus ring: 2px accent-strong, 2px outside the field.
private struct SFFieldStyle: ViewModifier {
    var isFocused = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: 50)
            .foregroundStyle(Color.sfInk)
            .background(Color.sfSurface200)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.sfBorderStrong, lineWidth: 1))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.sfAccentStrong, lineWidth: 2)
                    .padding(-3)
                    .opacity(isFocused ? 1 : 0)
            )
            .animation(.easeOut(duration: 0.12), value: isFocused)
    }
}
