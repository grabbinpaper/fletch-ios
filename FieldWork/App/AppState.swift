import SwiftUI
import SwiftData

@Observable
final class AppState {
    var isAuthenticated = false
    var isCheckingAuth = true
    var staffId: UUID?
    var organizationId: UUID?
    var crewId: UUID?
    var staffName: String = ""

    let modelContainer: ModelContainer
    let authManager: AuthManager
    let supabaseManager: SupabaseManager
    let networkMonitor: NetworkMonitor
    let syncEngine: SyncEngine
    let locationManager: LocationManager

    init() {
        let schema = Schema([
            CachedBooking.self,
            CachedSurface.self,
            CachedBacksplash.self,
            CachedMeasurement.self,
            CachedCutout.self,
            CachedVisit.self,
            CachedChecklistItem.self,
            CachedPhoto.self,
            SyncOperation.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        // swiftlint:disable:next force_try
        self.modelContainer = try! ModelContainer(for: schema, configurations: [config])

        self.supabaseManager = SupabaseManager()
        self.authManager = AuthManager(supabase: supabaseManager)
        self.networkMonitor = NetworkMonitor()
        self.syncEngine = SyncEngine(
            supabase: supabaseManager,
            modelContainer: modelContainer,
            networkMonitor: networkMonitor
        )
        self.locationManager = LocationManager()
    }

    func checkExistingSession() async {
        defer { isCheckingAuth = false }

        guard let session = await authManager.restoreSession() else {
            return
        }

        await loadUserContext(authProviderId: session.user.id.uuidString)
    }

    func signIn(authProviderId: String) async {
        await loadUserContext(authProviderId: authProviderId)
    }

    func signOut() async {
        await authManager.signOut()
        staffId = nil
        organizationId = nil
        crewId = nil
        staffName = ""
        isAuthenticated = false
    }

    private func loadUserContext(authProviderId: String) async {
        let normalizedId = authProviderId.lowercased()
        do {
            NSLog("[FieldWork] Loading user context for auth ID: %@", normalizedId)

            // Look up user_account by auth_provider_id
            let userAccount: UserAccount = try await supabaseManager.client
                .from("user_account")
                .select()
                .eq("auth_provider_id", value: normalizedId)
                .eq("is_active", value: true)
                .single()
                .execute()
                .value

            self.staffId = userAccount.staffId
            self.organizationId = userAccount.organizationId
            NSLog("[FieldWork] Found user account, staffId: %@", userAccount.staffId.uuidString)

            // Look up staff name
            let staff: Staff = try await supabaseManager.client
                .from("staff")
                .select()
                .eq("staff_id", value: userAccount.staffId.uuidString)
                .single()
                .execute()
                .value

            self.staffName = staff.preferredName ?? staff.firstName
            NSLog("[FieldWork] Staff name: %@", self.staffName)

            // Look up crew membership
            let crewMembers: [CrewMember] = try await supabaseManager.client
                .from("crew_member")
                .select()
                .eq("staff_id", value: userAccount.staffId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value

            self.crewId = crewMembers.first?.crewId
            self.isAuthenticated = true
            NSLog("[FieldWork] Auth complete. crewId: %@", crewId?.uuidString ?? "nil")
        } catch {
            NSLog("[FieldWork] Failed to load user context: %@", "\(error)")
            self.isAuthenticated = false
        }
    }
}
