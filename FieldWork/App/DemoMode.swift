#if DEBUG
import Foundation
import SwiftData

/// Development-only demo: signs in as a sample tech and fills today's schedule with sample jobs,
/// so screens can be reviewed without a Fletch login. Never compiled into release builds.
/// Start it from "Open demo" on the login screen, or launch with `-FieldWorkDemo YES`.
enum DemoMode {
    static var requestedAtLaunch: Bool {
        UserDefaults.standard.bool(forKey: "FieldWorkDemo")
    }

    /// Where in the day the demo starts: `-FieldWorkDemoStage morning|midday|done` (default midday).
    enum Stage: String {
        case morning, midday, done
    }

    static var stage: Stage {
        UserDefaults.standard.string(forKey: "FieldWorkDemoStage").flatMap(Stage.init(rawValue:)) ?? .midday
    }

    static let staffId = UUID(uuidString: "D0000000-0000-4000-8000-000000000001")!
    static let organizationId = UUID(uuidString: "D0000000-0000-4000-8000-000000000002")!
    static let crewId = UUID(uuidString: "D0000000-0000-4000-8000-000000000003")!

    /// Fixed IDs so reopening the demo updates the same jobs instead of piling up copies.
    static let bookingIds: [UUID] = (1...8).map {
        UUID(uuidString: String(format: "D0000000-0000-4000-8000-0000000001%02d", $0))!
    }

    /// Puts the sample jobs (today and tomorrow) on the phone.
    @MainActor
    static func seed(into context: ModelContext) {
        let bookings = sampleBookings()
        ScheduleViewModel.upsertBookings(bookings, in: context)
    }

    /// Takes the sample jobs back off the phone.
    @MainActor
    static func clear(from context: ModelContext) {
        let ids = bookingIds
        let descriptor = FetchDescriptor<CachedBooking>(predicate: #Predicate { ids.contains($0.bookingId) })
        for booking in (try? context.fetch(descriptor)) ?? [] {
            context.delete(booking)
        }
        try? context.save()
    }

    // MARK: - Sample data

    private struct Sample {
        let hour: Int
        let minute: Int
        let hours: Double
        let install: Bool
        let priority: String
        let visitStatus: String?
        let jobNumber: String
        let customer: String
        let street: String
        let city: String
        let salesperson: String
        let surfaces: [(room: String, name: String, sqft: Double)]
        /// 0 for today, 1 for tomorrow.
        var dayOffset = 0
    }

    private static let samples: [Sample] = [
        Sample(hour: 7, minute: 30, hours: 1.5, install: false, priority: "standard", visitStatus: "completed",
               jobNumber: "J-20466", customer: "Martinez Residence", street: "4127 Bluebonnet Dr", city: "Plano",
               salesperson: "Karen Lee",
               surfaces: [("Kitchen", "Perimeter", 38), ("Kitchen", "Island", 24)]),
        Sample(hour: 9, minute: 30, hours: 2, install: false, priority: "standard", visitStatus: "on_site",
               jobNumber: "J-20481", customer: "Hollis Kitchen Remodel", street: "88 Creekview Ln", city: "Frisco",
               salesperson: "Karen Lee",
               surfaces: [("Kitchen", "Perimeter", 42), ("Kitchen", "Island", 30), ("Laundry", "Counter", 12)]),
        Sample(hour: 11, minute: 30, hours: 4, install: true, priority: "rush", visitStatus: nil,
               jobNumber: "J-20412", customer: "Thompson Builders", street: "1200 Elm St, Unit 4", city: "Dallas",
               salesperson: "Marcus Webb",
               surfaces: [("Kitchen", "Perimeter", 46), ("Kitchen", "Island", 28), ("Bar", "Top", 9)]),
        Sample(hour: 14, minute: 0, hours: 1.5, install: false, priority: "standard", visitStatus: nil,
               jobNumber: "J-20495", customer: "Patel Residence", street: "702 Willow Bend", city: "Allen",
               salesperson: "Marcus Webb",
               surfaces: [("Primary bath", "Vanity", 14), ("Guest bath", "Vanity", 8)]),
        Sample(hour: 16, minute: 0, hours: 1, install: false, priority: "remake", visitStatus: nil,
               jobNumber: "J-20377", customer: "Nguyen Residence", street: "3310 Ridgeline Ct", city: "McKinney",
               salesperson: "Karen Lee",
               surfaces: [("Kitchen", "Island", 26)]),
        // Tomorrow
        Sample(hour: 8, minute: 0, hours: 5, install: true, priority: "standard", visitStatus: nil,
               jobNumber: "J-20455", customer: "Brennan Residence", street: "1519 Oak Hollow Dr", city: "Prosper",
               salesperson: "Karen Lee",
               surfaces: [("Kitchen", "Perimeter", 40), ("Kitchen", "Island", 32)], dayOffset: 1),
        Sample(hour: 13, minute: 30, hours: 1.5, install: false, priority: "standard", visitStatus: nil,
               jobNumber: "J-20502", customer: "Okafor Residence", street: "60 Lakeside Cir", city: "Little Elm",
               salesperson: "Marcus Webb",
               surfaces: [("Kitchen", "Perimeter", 36), ("Kitchen", "Island", 20)], dayOffset: 1),
        Sample(hour: 15, minute: 30, hours: 1, install: false, priority: "rush", visitStatus: nil,
               jobNumber: "J-20509", customer: "Reyes Dental Office", street: "4400 Legacy Dr, Suite 120", city: "Plano",
               salesperson: "Marcus Webb",
               surfaces: [("Break room", "Counter", 18)], dayOffset: 1),
    ]

    private static func sampleBookings() -> [ScheduleBooking] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let iso = ISO8601DateFormatter()
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        day.locale = Locale(identifier: "en_US_POSIX")

        let json: [[String: Any]] = samples.enumerated().map { index, sample in
            let visitStatus: String? = switch (sample.dayOffset, stage) {
            case (0, .midday): sample.visitStatus
            case (0, .done): "completed"
            default: nil
            }
            let date = calendar.date(byAdding: .day, value: sample.dayOffset, to: today)!
            let start = calendar.date(bySettingHour: sample.hour, minute: sample.minute, second: 0, of: date)!
            let end = start.addingTimeInterval(sample.hours * 3600)
            let id = bookingIds[index]
            func subId(_ n: Int) -> String {
                id.uuidString.replacingOccurrences(of: "-8000-", with: String(format: "-%04d-", 8100 + n))
            }

            var booking: [String: Any] = [
                "booking_id": id.uuidString,
                "scheduled_date": day.string(from: date),
                "start_datetime": iso.string(from: start),
                "end_datetime": iso.string(from: end),
                "status": visitStatus == "completed" ? "completed" : "scheduled",
                "priority": sample.priority,
                "service": [
                    "service_id": subId(1),
                    "name": sample.install ? "Install" : "Template",
                    "code": sample.install ? "INST" : "TMPL",
                    "visit_type_code": sample.install ? "INST" : "TMPL",
                ],
                "job": [
                    "job_id": subId(2),
                    "job_number": sample.jobNumber,
                    "status": "active",
                    "priority": sample.priority,
                    "site_address_line1": sample.street,
                    "site_city": sample.city,
                    "site_state": "TX",
                    "salesperson_name": sample.salesperson,
                ],
                "customer": [
                    "customer_id": subId(3),
                    "name": sample.customer,
                ],
                "surfaces": sample.surfaces.enumerated().map { n, surface in
                    [
                        "surface_id": subId(10 + n),
                        "name": surface.name,
                        "room_name": surface.room,
                        "display_order": n,
                        "estimated_sqft": surface.sqft,
                        "backsplash_pieces": [] as [Any],
                    ] as [String: Any]
                },
            ]
            if let status = visitStatus {
                var visit: [String: Any] = ["visit_id": subId(4), "status": status]
                if status != "en_route" { visit["arrived_at"] = iso.string(from: start) }
                if status == "completed" { visit["completed_at"] = iso.string(from: end) }
                booking["visit"] = visit
            }
            return booking
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            return try JSONDecoder().decode([ScheduleBooking].self, from: data)
        } catch {
            NSLog("[FieldWork] Demo data failed to decode: %@", "\(error)")
            return []
        }
    }
}
#endif
