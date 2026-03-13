import Foundation
import AuthenticationServices
import Supabase

@Observable
final class AuthManager {
    private let supabase: SupabaseManager

    var isSigningIn = false
    var errorMessage: String?

    init(supabase: SupabaseManager) {
        self.supabase = supabase
    }

    func restoreSession() async -> Session? {
        try? await supabase.client.auth.session
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> String {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8)
        else {
            throw AuthError.missingIdentityToken
        }

        let session = try await supabase.client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: tokenString
            )
        )

        return session.user.id.uuidString
    }

    func signInWithEmail(email: String, password: String) async throws -> String {
        let session = try await supabase.client.auth.signIn(
            email: email,
            password: password
        )
        return session.user.id.uuidString
    }

    func signOut() async {
        try? await supabase.client.auth.signOut()
    }
}

enum AuthError: LocalizedError {
    case missingIdentityToken
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Could not retrieve identity token from Apple Sign-In."
        case .userNotFound:
            return "No user account found. Contact your administrator."
        }
    }
}
