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
    /// Signed in to the development-only demo (sample jobs, no server).
    var isDemo = false

    // Active visit tracking for tab navigation
    var activeBooking: CachedBooking?
    var selectedTab: AppTab = .home
    /// Which day the Schedule tab shows (Home's "See tomorrow" switches it).
    var scheduleDay: ScheduleDay = .today
    /// Shown once as a banner on Home after a visit is finished ("Visit complete · Kip Lewis").
    var visitCompletedNotice: String?

    /// A visit is finished and nothing else is needed on it: back to Home, the Visit tab
    /// empties (and loses its badge), and Home says so.
    func finishActiveVisit(customerName: String?) {
        activeBooking = nil
        selectedTab = .home
        visitCompletedNotice = ["Visit complete", customerName].compactMap { $0 }.joined(separator: " · ")
    }

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
        self.authManager = AuthManager()
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

        #if DEBUG
        if DemoMode.requestedAtLaunch {
            await startDemo()
            return
        }
        #endif

        guard let clerkUserId = await authManager.restoreSession() else {
            return
        }

        await loadUserContext(clerkUserId: clerkUserId, email: nil)
    }

    func signIn(clerkUserId: String, email: String?) async {
        await loadUserContext(clerkUserId: clerkUserId, email: email)
    }

    func signOut() async {
        #if DEBUG
        if isDemo {
            let container = modelContainer
            await MainActor.run { DemoMode.clear(from: container.mainContext) }
            isDemo = false
        }
        #endif
        await authManager.signOut()
        staffId = nil
        organizationId = nil
        crewId = nil
        staffName = ""
        isAuthenticated = false
    }

    #if DEBUG
    /// Signs in as the demo tech with today's sample jobs. Development builds only.
    @MainActor
    func startDemo() {
        DemoMode.seed(into: modelContainer.mainContext)
        staffId = DemoMode.staffId
        organizationId = DemoMode.organizationId
        crewId = DemoMode.crewId
        staffName = "Dave"
        signInError = nil
        isDemo = true
        isAuthenticated = true
    }
    #endif

    private func loadUserContext(clerkUserId: String, email: String?) async {
        signInError = nil
        do {
            NSLog("[FieldWork] Loading user context for Clerk user: %@", clerkUserId)

            // The Fletch user this Clerk login belongs to (linked by Fletch's Clerk webhook)
            let userAccount: UserAccount = try await supabaseManager.client
                .from("user_account")
                .select()
                .eq("clerk_user_id", value: clerkUserId)
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

            #if DEBUG
            // A real sign-in must never show the demo's sample jobs left on the phone.
            let container = modelContainer
            await MainActor.run { DemoMode.clear(from: container.mainContext) }
            #endif

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
