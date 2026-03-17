import Foundation
import SwiftData

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
    func loadSchedule(context: ModelContext) async {
        guard let appState else {
            NSLog("[FieldWork] loadSchedule: appState is nil")
            return
        }

        isLoading = true
        error = nil

        let hasNetwork = appState.networkMonitor.isConnected
        let staffId = appState.staffId
        NSLog("[FieldWork] loadSchedule: network=%d staffId=%@", hasNetwork ? 1 : 0, staffId?.uuidString ?? "nil")

        // Try to load from remote first
        if hasNetwork, let staffId {
            do {
                NSLog("[FieldWork] Fetching schedule for staff: %@ date: %@", staffId.uuidString, Date.todayString)
                let response: ScheduleResponse = try await appState.supabaseManager.client
                    .rpc("get_tech_schedule", params: [
                        "p_staff_id": staffId.uuidString,
                        "p_date": Date.todayString
                    ])
                    .execute()
                    .value

                NSLog("[FieldWork] Decoded %d bookings", response.bookings.count)

                // Upsert into SwiftData
                upsertBookings(response.bookings, in: context)
                lastRefreshed = Date()
            } catch {
                self.error = "Failed to load schedule: \(error)"
                NSLog("[FieldWork] Schedule load error: %@", "\(error)")
            }
        } else if staffId == nil {
            self.error = "Not signed in"
        }

        // Always read from local cache
        loadFromCache(context: context)
        NSLog("[FieldWork] loadFromCache returned %d bookings", bookings.count)
        isLoading = false
    }

    func loadFromCache(context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let descriptor = FetchDescriptor<CachedBooking>(
            predicate: #Predicate<CachedBooking> {
                $0.scheduledDate >= today && $0.scheduledDate < tomorrow
            },
            sortBy: [SortDescriptor(\.startDatetime)]
        )

        bookings = (try? context.fetch(descriptor)) ?? []
    }

    private func upsertBookings(_ remoteBookings: [ScheduleBooking], in context: ModelContext) {
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
