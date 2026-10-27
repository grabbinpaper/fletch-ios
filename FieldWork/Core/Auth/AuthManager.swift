import Foundation
import ClerkKit

/// Signs the tech in with Clerk, the same login as the Fletch website.
/// Clerk keeps the sign-in on the device; the Supabase client and the website's FieldWork API
/// are handed Clerk's session token on every request (`SupabaseManager.clerkSessionToken()`).
@MainActor
final class AuthManager {
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

    /// Signs in and returns the Clerk user id.
    func signInWithEmail(email: String, password: String) async throws -> String {
        let signIn = try await Clerk.shared.auth.signInWithPassword(identifier: email, password: password)
        switch signIn.status {
        case .complete:
            break
        case .needsSecondFactor:
            throw AuthError.needsSecondFactor
        case .needsNewPassword:
            throw AuthError.needsNewPassword
        default:
            throw AuthError.notFinished
        }
        guard let userId = Clerk.shared.user?.id else { throw AuthError.notFinished }
        return userId
    }

    func signOut() async {
        try? await Clerk.shared.auth.signOut()
    }
}

enum AuthError: LocalizedError {
    case needsSecondFactor
    case needsNewPassword
    case notFinished

    var errorDescription: String? {
        switch self {
        case .needsSecondFactor:
            return "This login needs a second sign-in step, which FieldWork doesn't support yet. Sign in on the Fletch website to check it."
        case .needsNewPassword:
            return "This login needs a new password. Set one on the Fletch website, then sign in here."
        case .notFinished:
            return "Couldn't finish signing in. Try again."
        }
    }
}
