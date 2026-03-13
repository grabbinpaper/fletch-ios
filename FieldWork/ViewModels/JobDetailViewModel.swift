import Foundation
import SwiftData
import MapKit

@Observable
final class JobDetailViewModel {
    var booking: CachedBooking
    var isStartingVisit = false
    var isArrivingAtSite = false
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
        default: return .notStarted
        }
    }

    var ctaTitle: String {
        switch visitState {
        case .notStarted: return "Start Visit"
        case .enRoute: return "Arrived on Site"
        case .onSite: return "Continue Visit"
        case .completed: return "View Summary"
        }
    }

    @MainActor
    func startVisit(context: ModelContext) async {
        guard let appState, let staffId = appState.staffId else { return }

        isStartingVisit = true
        error = nil

        do {
            let lat = appState.locationManager.latitude
            let lng = appState.locationManager.longitude

            let visitId: UUID = try await appState.supabaseManager.client
                .rpc("start_template_visit", params: [
                    "p_booking_id": booking.bookingId.uuidString,
                    "p_worker_id": staffId.uuidString,
                    "p_lat": lat.map { "\($0)" } ?? "",
                    "p_lng": lng.map { "\($0)" } ?? ""
                ])
                .execute()
                .value

            booking.visitId = visitId
            booking.visitStatus = "en_route"
            booking.visitDepartedAt = Date()
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

            try await appState.supabaseManager.client
                .rpc("arrive_at_site", params: [
                    "p_visit_id": visitId.uuidString,
                    "p_lat": lat.map { "\($0)" } ?? "",
                    "p_lng": lng.map { "\($0)" } ?? ""
                ])
                .execute()

            booking.visitStatus = "on_site"
            booking.visitArrivedAt = Date()
            try? context.save()
        } catch {
            self.error = "Failed to record arrival: \(error.localizedDescription)"
        }

        isArrivingAtSite = false
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
}
