import Foundation
import SwiftData

/// The day the Schedule tab is showing. Crews only look one day ahead.
enum ScheduleDay: String, CaseIterable {
    case today, tomorrow

    var title: String { self == .today ? "Today" : "Tomorrow" }

    /// Start of this day on the phone's calendar.
    var date: Date {
        let today = Calendar.current.startOfDay(for: Date())
        return self == .today ? today : Calendar.current.date(byAdding: .day, value: 1, to: today)!
    }

    /// "yyyy-MM-dd", as the schedule RPC takes it.
    var apiString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// "Wednesday, Oct 28"
    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

@Observable
final class ScheduleViewModel {
    var bookings: [CachedBooking] = []
    var isLoading = false
    var error: String?
    var lastRefreshed: Date?

    private var appState: AppState?

    func configure(appState: AppState) {
        self.appState = appState
    }

    var inProgressBookings: [CachedBooking] {
        bookings.filter { $0.visitStatus == "en_route" || $0.visitStatus == "on_site" }
    }

    var upcomingBookings: [CachedBooking] {
        bookings.filter {
            $0.status != "completed" && $0.status != "cancelled"
            && $0.visitStatus != "en_route" && $0.visitStatus != "on_site"
            && $0.visitStatus != "completed"
        }
    }

    var completedBookings: [CachedBooking] {
        bookings.filter { $0.visitStatus == "completed" || $0.status == "completed" }
    }

    @MainActor
    func loadSchedule(context: ModelContext, day: ScheduleDay = .today) async {
        guard let appState else {
            NSLog("[FieldWork] loadSchedule: appState is nil")
            return
        }

        isLoading = true
        error = nil

        // The demo's jobs live only on the phone; there's no server schedule to fetch.
        if appState.isDemo {
            loadFromCache(context: context, day: day)
            isLoading = false
            return
        }

        let hasNetwork = appState.networkMonitor.isConnected
        let staffId = appState.staffId
        NSLog("[FieldWork] loadSchedule: network=%d staffId=%@", hasNetwork ? 1 : 0, staffId?.uuidString ?? "nil")

        // Try to load from remote first
        if hasNetwork, let staffId {
            do {
                NSLog("[FieldWork] Fetching schedule for staff: %@ date: %@", staffId.uuidString, day.apiString)
                let remoteBookings = try await Self.fetchBookings(appState: appState, staffId: staffId, date: day.apiString)
                NSLog("[FieldWork] Decoded %d bookings", remoteBookings.count)

                // Upsert into SwiftData
                Self.upsertBookings(remoteBookings, in: context)
                lastRefreshed = Date()
            } catch {
                self.error = "Failed to load schedule: \(error)"
                NSLog("[FieldWork] Schedule load error: %@", "\(error)")
            }
        } else if staffId == nil {
            self.error = "Not signed in"
        }

        // Visits are booked to crews; a tech who isn't on one would just see "No Jobs Today".
        if staffId != nil && appState.crewId == nil && error == nil {
            self.error = "You're not on a crew in Fletch, so no visits can show here. Ask the office to add you to a crew."
        }

        // Always read from local cache
        loadFromCache(context: context, day: day)
        NSLog("[FieldWork] loadFromCache returned %d bookings", bookings.count)
        isLoading = false
    }

    func loadFromCache(context: ModelContext, day: ScheduleDay = .today) {
        bookings = (try? context.fetch(Self.bookingsDescriptor(for: day))) ?? []
    }

    /// Today's bookings stored on the phone, earliest first (Schedule and Home tabs).
    static func todaysBookingsDescriptor() -> FetchDescriptor<CachedBooking> {
        bookingsDescriptor(for: .today)
    }

    /// One day's bookings stored on the phone, earliest first.
    static func bookingsDescriptor(for day: ScheduleDay) -> FetchDescriptor<CachedBooking> {
        let start = day.date
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return FetchDescriptor<CachedBooking>(
            predicate: #Predicate<CachedBooking> {
                $0.scheduledDate >= start && $0.scheduledDate < end
            },
            sortBy: [SortDescriptor(\.startDatetime)]
        )
    }

    /// Today's bookings for this tech, straight from the server.
    static func fetchTodaysBookings(appState: AppState, staffId: UUID) async throws -> [ScheduleBooking] {
        try await fetchBookings(appState: appState, staffId: staffId, date: ScheduleDay.today.apiString)
    }

    /// One day's bookings for this tech ("yyyy-MM-dd"), straight from the server.
    static func fetchBookings(appState: AppState, staffId: UUID, date: String) async throws -> [ScheduleBooking] {
        let response: ScheduleResponse = try await appState.supabaseManager.client
            .rpc("get_tech_schedule", params: [
                "p_staff_id": staffId.uuidString,
                "p_date": date
            ])
            .execute()
            .value
        return response.bookings
    }

    static func upsertBookings(_ remoteBookings: [ScheduleBooking], in context: ModelContext) {
        for remote in remoteBookings {
            let bookingId = remote.bookingId
            let descriptor = FetchDescriptor<CachedBooking>(
                predicate: #Predicate<CachedBooking> { $0.bookingId == bookingId }
            )

            if let existing = try? context.fetch(descriptor).first {
                existing.update(from: remote)
            } else {
                let cached = CachedBooking(from: remote)
                context.insert(cached)
            }
        }

        try? context.save()
    }
}
