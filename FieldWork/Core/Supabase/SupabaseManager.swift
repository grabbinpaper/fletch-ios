import Foundation
import Supabase

final class SupabaseManager: Sendable {
    let client: SupabaseClient

    init() {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_HOST") as? String,
              !host.isEmpty,
              let url = URL(string: "https://\(host)"),
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        else {
            fatalError("Missing SUPABASE_HOST or SUPABASE_ANON_KEY in Info.plist")
        }

        self.client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }
}

/// Calls to the Fletch website for things the database can't do itself (texting / emailing the
/// customer). The site checks the FieldWork sign-in (`/api/fieldwork/*`).
/// Its address is WEB_APP_URL in Config/Debug.xcconfig (via Info.plist).
enum FieldworkWebAPI {
    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static var baseURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "WEB_APP_URL") as? String)
            .flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    /// Text or email the visit's sign-off link to the customer.
    static func sendSignoff(
        visitId: UUID, channel: SignoffChannel, address: String, name: String?, appState: AppState
    ) async throws {
        guard let baseURL else { throw APIError(message: "The website address (WEB_APP_URL) isn't set in this build") }
        let session = try await appState.supabaseManager.client.auth.session

        var request = URLRequest(url: baseURL.appendingPathComponent("api/fieldwork/send-signoff"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "visitId": visitId.uuidString,
            "channel": channel.rawValue,
            "address": address,
            "name": name ?? NSNull(),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw APIError(message: message ?? "Couldn't send the sign-off link")
        }
    }
}
