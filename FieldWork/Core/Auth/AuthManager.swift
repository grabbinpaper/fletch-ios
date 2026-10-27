import Foundation
import ClerkKit

/// Signs the tech in with Clerk, the same login as the Fletch website.
/// Clerk keeps the sign-in on the device; the Supabase client and the website's FieldWork API
/// are handed Clerk's session token on every request (`SupabaseManager.clerkSessionToken()`).
@MainActor
final class AuthManager {
    /// Where a sign-in stands after the password (or a code).
    enum SignInStep {
        /// Signed in: the Clerk user id.
        case signedIn(String)
        /// Clerk wants a code too (a new device, or the login has two-step verification).
        case needsCode(CodePrompt)
    }

    /// The code Clerk asked for, and how to tell the tech where to find it.
    struct CodePrompt {
        let signIn: SignIn
        let type: SignIn.MfaType
        let message: String
    }

    /// Starts Clerk. Call once at launch, before anything signs in or reads the session.
    static func configure() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "CLERK_PUBLISHABLE_KEY") as? String,
              key.hasPrefix("pk_")
        else {
            fatalError("Missing CLERK_PUBLISHABLE_KEY in Info.plist (set it in Config/Debug.xcconfig)")
        }
        Clerk.configure(publishableKey: key)
    }

    /// The Clerk user id of the sign-in saved on this phone, once Clerk has loaded it; nil if signed out.
    func restoreSession() async -> String? {
        // Clerk loads the saved sign-in in the background at launch; give it a few seconds.
        for _ in 0..<50 where !Clerk.shared.isLoaded {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return Clerk.shared.user?.id
    }

    /// Signs in with email and password. Clerk may then want a code; it's sent here when it comes
    /// by email or text, and checked with `verifyCode`.
    func signInWithEmail(email: String, password: String) async throws -> SignInStep {
        let signIn = try await Clerk.shared.auth.signInWithPassword(identifier: email, password: password)
        return try await step(after: signIn)
    }

    /// Checks the code from `CodePrompt` and finishes signing in.
    func verifyCode(_ code: String, for prompt: CodePrompt) async throws -> SignInStep {
        let signIn = try await prompt.signIn.verifyMfaCode(code, type: prompt.type)
        return try await step(after: signIn)
    }

    func signOut() async {
        try? await Clerk.shared.auth.signOut()
    }

    private func step(after signIn: SignIn) async throws -> SignInStep {
        switch signIn.status {
        case .complete:
            guard let userId = Clerk.shared.user?.id else { throw AuthError.notFinished }
            return .signedIn(userId)
        case .needsSecondFactor:
            return .needsCode(try await codePrompt(for: signIn))
        case .needsNewPassword:
            throw AuthError.needsNewPassword
        default:
            throw AuthError.notFinished
        }
    }

    /// Picks how the code arrives, preferring one that needs nothing sent, and sends it if needed.
    private func codePrompt(for signIn: SignIn) async throws -> CodePrompt {
        let strategies = (signIn.supportedSecondFactors ?? []).map(\.strategy)
        if strategies.contains(.totp) {
            return CodePrompt(signIn: signIn, type: .totp,
                              message: "Enter the 6-digit code from your authenticator app.")
        }
        if strategies.contains(.emailCode) {
            let sent = try await signIn.sendMfaEmailCode()
            return CodePrompt(signIn: sent, type: .emailCode,
                              message: "We emailed you a code. Enter it to finish signing in.")
        }
        if strategies.contains(.phoneCode) {
            let sent = try await signIn.sendMfaPhoneCode()
            return CodePrompt(signIn: sent, type: .phoneCode,
                              message: "We texted you a code. Enter it to finish signing in.")
        }
        if strategies.contains(.backupCode) {
            return CodePrompt(signIn: signIn, type: .backupCode,
                              message: "Enter one of your backup codes.")
        }
        throw AuthError.unsupportedSecondStep
    }
}

enum AuthError: LocalizedError {
    case unsupportedSecondStep
    case needsNewPassword
    case notFinished

    var errorDescription: String? {
        switch self {
        case .unsupportedSecondStep:
            return "This login needs a second sign-in step FieldWork can't do yet. Sign in on the Fletch website to check it."
        case .needsNewPassword:
            return "This login needs a new password. Set one on the Fletch website, then sign in here."
        case .notFinished:
            return "Couldn't finish signing in. Try again."
        }
    }
}
