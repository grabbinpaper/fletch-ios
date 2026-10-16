import SwiftUI
import SwiftData
import Supabase

@Observable
final class AppState {
    var isAuthenticated = false
    var isCheckingAuth = true
    var staffId: UUID?
    var organizationId: UUID?
    var crewId: UUID?
    var staffName: String = ""
    /// Why the last sign-in didn't get past the login screen (shown there).
    var signInError: String?

    // Active visit tracking for tab navigation
    var activeBooking: CachedBooking?
    var selectedTab: AppTab = .home

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
            CachedBacksplashMeasurement.self,
            CachedVisit.self,
            CachedChecklistItem.self,
            CachedPhoto.self,
            SyncOperation.self,
            CachedSurfaceStatus.self
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

        // Work done offline (measurements, photos, checklist answers…) waits in the sync
        // queue. Send it as soon as the phone is back online, without the tech doing anything.
        let syncEngine = self.syncEngine
        networkMonitor.onReconnect = {
            Task { await syncEngine.processPendingOperations() }
        }
    }

    func checkExistingSession() async {
        defer { isCheckingAuth = false }

        guard let session = await authManager.restoreSession() else {
            return
        }

        await loadUserContext(authProviderId: session.user.id.uuidString, email: session.user.email)
    }

    func signIn(authProviderId: String, email: String?) async {
        await loadUserContext(authProviderId: authProviderId, email: email)
    }

    func signOut() async {
        await authManager.signOut()
        staffId = nil
        organizationId = nil
        crewId = nil
        staffName = ""
        isAuthenticated = false
    }

    private func loadUserContext(authProviderId: String, email: String?) async {
        let normalizedId = authProviderId.lowercased()
        signInError = nil
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

            // Anything still queued from last time (e.g. the app was closed while offline).
            let syncEngine = self.syncEngine
            Task { await syncEngine.processPendingOperations() }
        } catch {
            // The password was right, but we couldn't load who this is in Fletch. Say so
            // (this used to leave the tech on the login screen with no message).
            NSLog("[FieldWork] Failed to load user context: %@", "\(error)")
            let who = email ?? "this login"
            self.isAuthenticated = false
            if let postgrest = error as? PostgrestError, postgrest.code == "PGRST116" {
                // Not linked to a tech: drop the sign-in so the next launch doesn't silently retry it.
                signInError = "Signed in, but \(who) isn't linked to a field tech in Fletch yet. Ask the office to link it."
                await authManager.signOut()
            } else {
                // Usually no signal. Keep the saved session so the next launch with signal works
                // without retyping the password (which a tech can't do offline anyway).
                signInError = "Signed in, but couldn't load your Fletch profile: \(error.localizedDescription)"
            }
        }
    }
}
