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
