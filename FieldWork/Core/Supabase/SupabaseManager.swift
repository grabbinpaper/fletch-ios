import Foundation
import Supabase

final class SupabaseManager: Sendable {
    let client: SupabaseClient

    init() {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlString),
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        else {
            fatalError("Missing SUPABASE_URL or SUPABASE_ANON_KEY in Info.plist")
        }

        self.client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }
}
