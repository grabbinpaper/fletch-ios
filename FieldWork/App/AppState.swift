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

    // TODO: remove after screenshots
    @MainActor
    func demoSignIn() {
        self.staffId = UUID()
        self.organizationId = UUID()
        self.crewId = UUID()
        self.staffName = "Mike"
        self.isAuthenticated = true
        self.isCheckingAuth = false

        // Seed demo bookings into SwiftData
        let context = modelContainer.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<CachedBooking>())) ?? 0
        guard existing == 0 else { return }

        let today = Calendar.current.startOfDay(for: Date())

        let b1 = CachedBooking.demo(
            jobNumber: "4521",
            customerName: "Johnson Residence",
            serviceName: "Template",
            priority: "standard",
            constructionType: "new_construction",
            startTime: today.addingTimeInterval(9 * 3600),  // 9 AM
            address: "742 Evergreen Terrace",
            city: "Springfield", state: "IL", zip: "62704",
            salesperson: "Sarah Chen",
            salespersonPhone: "(555) 123-4567",
            contactName: "Tom Johnson",
            contactPhone: "(555) 987-6543",
            surfaces: [
                ("Kitchen", nil, "Countertop", 45.0, 96.0, 25.5),
                ("Kitchen", nil, "Island", 22.0, 72.0, 36.0),
                ("Master Bath", nil, "Vanity", 12.0, 48.0, 22.0),
            ]
        )

        let b2 = CachedBooking.demo(
            jobNumber: "4522",
            customerName: "Riverside Office Park",
            serviceName: "Template",
            priority: "rush",
            constructionType: "remodel",
            startTime: today.addingTimeInterval(13 * 3600), // 1 PM
            address: "200 Commerce Dr, Suite 100",
            city: "Springfield", state: "IL", zip: "62701",
            salesperson: "Mike Rivera",
            salespersonPhone: "(555) 222-3344",
            contactName: "Lisa Park",
            contactPhone: "(555) 444-5566",
            tearoutRequired: true,
            specialInstructions: "Old laminate countertops need removal. Dumpster on-site.",
            surfaces: [
                ("Break Room", nil, "Countertop", 30.0, 84.0, 25.5),
                ("Executive Bath", nil, "Vanity", 15.0, 60.0, 22.0),
            ]
        )

        let b3 = CachedBooking.demo(
            jobNumber: "4519",
            customerName: "Martinez Kitchen Remodel",
            serviceName: "Template",
            priority: "standard",
            constructionType: "remodel",
            startTime: today.addingTimeInterval(15.5 * 3600), // 3:30 PM
            address: "1847 Oak Valley Rd",
            city: "Springfield", state: "IL", zip: "62711",
            salesperson: "Sarah Chen",
            salespersonPhone: "(555) 123-4567",
            contactName: "Maria Martinez",
            contactPhone: "(555) 777-8899",
            plumbingDisconnect: true,
            siteAccessNotes: "Gate code: 4421. Dog in backyard, use front door.",
            surfaces: [
                ("Kitchen", nil, "Countertop", 38.0, 108.0, 25.5),
                ("Kitchen", nil, "Island", 28.0, 84.0, 36.0),
                ("Kitchen", "Left", "Peninsula", 18.0, 60.0, 25.5),
                ("Laundry", nil, "Countertop", 8.0, 36.0, 22.0),
            ]
        )

        // Install visit demo bookings
        let b4 = CachedBooking.demo(
            jobNumber: "4515",
            customerName: "Anderson Kitchen",
            serviceName: "Install",
            serviceCode: "install",
            priority: "standard",
            constructionType: "remodel",
            startTime: today.addingTimeInterval(10.5 * 3600), // 10:30 AM
            address: "328 Maple Ave",
            city: "Springfield", state: "IL", zip: "62702",
            salesperson: "Sarah Chen",
            salespersonPhone: "(555) 123-4567",
            contactName: "David Anderson",
            contactPhone: "(555) 333-2211",
            tearoutRequired: true,
            specialInstructions: "Old tile countertops — tearout by GC should be done.",
            surfaces: [
                ("Kitchen", nil, "Countertop", 42.0, 96.0, 25.5),
                ("Kitchen", nil, "Island", 24.0, 72.0, 36.0),
                ("Kitchen", nil, "Backsplash", 18.0, 120.0, 4.0),
            ]
        )

        let b5 = CachedBooking.demo(
            jobNumber: "4518",
            customerName: "Greenfield Builders — Lot 14",
            serviceName: "Install",
            serviceCode: "install",
            priority: "standard",
            constructionType: "new_construction",
            startTime: today.addingTimeInterval(14 * 3600), // 2 PM
            address: "14 Greenfield Estates Dr",
            city: "Springfield", state: "IL", zip: "62712",
            salesperson: "Mike Rivera",
            salespersonPhone: "(555) 222-3344",
            contactName: "Jake Greenfield",
            contactPhone: "(555) 888-9900",
            surfaces: [
                ("Kitchen", nil, "Countertop", 55.0, 120.0, 25.5),
                ("Kitchen", nil, "Island", 32.0, 96.0, 36.0),
                ("Master Bath", nil, "Vanity", 16.0, 60.0, 22.0),
                ("Guest Bath", nil, "Vanity", 8.0, 36.0, 22.0),
                ("Laundry", nil, "Countertop", 6.0, 30.0, 22.0),
            ]
        )

        context.insert(b1)
        context.insert(b2)
        context.insert(b3)
        context.insert(b4)
        context.insert(b5)
        try? context.save()
        NSLog("[FieldWork] Seeded 5 demo bookings (3 template, 2 install)")
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
