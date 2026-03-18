import Foundation
import SwiftData
import MapKit

@Observable
final class JobDetailViewModel {
    var booking: CachedBooking
    var isStartingVisit = false
    var isArrivingAtSite = false
    var isReportingBlocked = false
    var didReportBlocked = false
    var error: String?

    private var appState: AppState?

    init(booking: CachedBooking) {
        self.booking = booking
    }

    func configure(appState: AppState) {
        self.appState = appState
    }

    var visitState: VisitState {
        guard let status = booking.visitStatus else { return .notStarted }
        switch status {
        case "en_route": return .enRoute
        case "on_site": return .onSite
        case "completed": return .completed
        case "blocked": return .blocked
        default: return .notStarted
        }
    }

    var canReportBlocked: Bool {
        let state = visitState
        return state == .notStarted || state == .enRoute || state == .onSite
    }

    var ctaTitle: String {
        switch visitState {
        case .notStarted: return "Start Visit"
        case .enRoute: return "Arrived on Site"
        case .onSite: return "Continue Visit"
        case .completed: return "View Summary"
        case .blocked: return "Visit Blocked"
        }
    }

    @MainActor
    func startVisit(startingAddress: String?, context: ModelContext) async {
        guard let appState, let staffId = appState.staffId else { return }

        isStartingVisit = true
        error = nil

        do {
            let lat = appState.locationManager.latitude
            let lng = appState.locationManager.longitude

            var params: [String: String] = [
                "p_booking_id": booking.bookingId.uuidString,
                "p_worker_id": staffId.uuidString,
                "p_lat": lat.map { "\($0)" } ?? "",
                "p_lng": lng.map { "\($0)" } ?? ""
            ]
            if let startingAddress, !startingAddress.isEmpty {
                params["p_starting_address"] = startingAddress
            }

            let visitId: UUID = try await appState.supabaseManager.client
                .rpc("start_template_visit", params: params)
                .execute()
                .value

            booking.visitId = visitId
            booking.visitStatus = "en_route"
            booking.visitDepartedAt = Date()
            booking.visitDepartureLat = lat
            booking.visitDepartureLng = lng
            booking.startingAddress = startingAddress
            booking.status = "in_progress"
            try? context.save()

            // Initialize checklist
            if let orgId = appState.organizationId {
                let _: UUID? = try? await appState.supabaseManager.client
                    .rpc("initialize_visit_checklist", params: [
                        "p_visit_id": visitId.uuidString,
                        "p_service_id": booking.serviceId.uuidString,
                        "p_org_id": orgId.uuidString
                    ])
                    .execute()
                    .value
            }
        } catch {
            self.error = "Failed to start visit: \(error.localizedDescription)"
        }

        isStartingVisit = false
    }

    @MainActor
    func arriveAtSite(context: ModelContext) async {
        guard let visitId = booking.visitId else { return }
        guard let appState else { return }

        isArrivingAtSite = true
        error = nil

        do {
            let lat = appState.locationManager.latitude
            let lng = appState.locationManager.longitude

            let result: ArrivalResponse = try await appState.supabaseManager.client
                .rpc("arrive_at_site", params: [
                    "p_visit_id": visitId.uuidString,
                    "p_lat": lat.map { "\($0)" } ?? "",
                    "p_lng": lng.map { "\($0)" } ?? ""
                ])
                .execute()
                .value

            booking.visitStatus = "on_site"
            booking.visitArrivedAt = Date()
            booking.travelMiles = result.calculatedMiles
            booking.travelTimeMinutes = result.travelTimeMinutes
            try? context.save()
        } catch {
            self.error = "Failed to record arrival: \(error.localizedDescription)"
        }

        isArrivingAtSite = false
    }

    @MainActor
    func reportBlocked(reason: BlockedReason, notes: String?, context: ModelContext) async {
        guard let appState, let staffId = appState.staffId else { return }

        // If no visit exists yet, create one first
        var visitId: UUID
        if let existing = booking.visitId {
            visitId = existing
        } else {
            do {
                let lat = appState.locationManager.latitude
                let lng = appState.locationManager.longitude
                var params: [String: String] = [
                    "p_booking_id": booking.bookingId.uuidString,
                    "p_worker_id": staffId.uuidString,
                    "p_lat": lat.map { "\($0)" } ?? "",
                    "p_lng": lng.map { "\($0)" } ?? ""
                ]
                let newVisitId: UUID = try await appState.supabaseManager.client
                    .rpc("start_template_visit", params: params)
                    .execute()
                    .value
                booking.visitId = newVisitId
                visitId = newVisitId
            } catch {
                self.error = "Failed to create visit: \(error.localizedDescription)"
                return
            }
        }

        isReportingBlocked = true
        error = nil

        let lat = appState.locationManager.latitude
        let lng = appState.locationManager.longitude
        let params: [String: String] = [
            "p_visit_id": visitId.uuidString,
            "p_worker_id": staffId.uuidString,
            "p_reason_code": reason.rawValue,
            "p_notes": notes ?? "",
            "p_lat": lat.map { "\($0)" } ?? "",
            "p_lng": lng.map { "\($0)" } ?? ""
        ]

        do {
            try await appState.supabaseManager.client
                .rpc("report_blocked_visit", params: params)
                .execute()

            booking.visitStatus = "blocked"
            booking.visitOutcome = "could_not_start"
            booking.status = "scheduled"
            try? context.save()

            didReportBlocked = true
        } catch {
            // Queue for offline sync
            if !appState.networkMonitor.isConnected {
                let payload = RPCPayload(functionName: "report_blocked_visit", params: params)
                if let data = try? JSONEncoder().encode(payload) {
                    await appState.syncEngine.queueOperation(
                        type: "rpc",
                        entityType: "visit",
                        entityId: visitId.uuidString,
                        payload: data,
                        in: context
                    )
                }

                booking.visitStatus = "blocked"
                booking.visitOutcome = "could_not_start"
                booking.status = "scheduled"
                try? context.save()

                didReportBlocked = true
            } else {
                self.error = "Failed to report blocked visit: \(error.localizedDescription)"
            }
        }

        isReportingBlocked = false
    }

    func openInMaps() {
        guard let lat = booking.siteLatitude, let lng = booking.siteLongitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = booking.customerName ?? "Job Site"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    func callPhone(_ number: String) {
        let cleaned = number.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}

enum VisitState {
    case notStarted
    case enRoute
    case onSite
    case completed
    case blocked
}

struct ArrivalResponse: Codable {
    let calculatedMiles: Double?
    let travelTimeMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case calculatedMiles = "calculated_miles"
        case travelTimeMinutes = "travel_time_minutes"
    }
}
