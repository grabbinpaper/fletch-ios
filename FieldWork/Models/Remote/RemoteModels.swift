import Foundation

// MARK: - User/Auth Models

struct UserAccount: Codable {
    let userId: UUID
    let organizationId: UUID
    let staffId: UUID
    let email: String
    let authProviderId: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case organizationId = "organization_id"
        case staffId = "staff_id"
        case email
        case authProviderId = "auth_provider_id"
        case isActive = "is_active"
    }
}

struct Staff: Codable {
    let staffId: UUID
    let organizationId: UUID
    let firstName: String
    let lastName: String
    let preferredName: String?
    let email: String?
    let phone: String?
    let mobile: String?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case staffId = "staff_id"
        case organizationId = "organization_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case preferredName = "preferred_name"
        case email, phone, mobile, title
    }
}

struct CrewMember: Codable {
    let crewMemberId: UUID
    let crewId: UUID
    let staffId: UUID?
    let firstName: String
    let lastName: String
    let isLead: Bool?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case crewMemberId = "crew_member_id"
        case crewId = "crew_id"
        case staffId = "staff_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case isLead = "is_lead"
        case isActive = "is_active"
    }
}

// MARK: - Schedule RPC Response

struct ScheduleResponse: Codable {
    let crewId: UUID?
    let bookings: [ScheduleBooking]

    enum CodingKeys: String, CodingKey {
        case crewId = "crew_id"
        case bookings
    }
}

struct ScheduleBooking: Codable, Identifiable {
    var id: UUID { bookingId }

    let bookingId: UUID
    let scheduledDate: String
    let startDatetime: String
    let endDatetime: String
    let arrivalWindowStart: String?
    let arrivalWindowEnd: String?
    let status: String
    let priority: String
    let siteAddress: String?
    let siteLatitude: Double?
    let siteLongitude: Double?
    let notes: String?
    let internalNotes: String?
    let service: ScheduleService
    let jobService: ScheduleJobService?
    let job: ScheduleJob?
    let customer: ScheduleCustomer?
    let contact: ScheduleContact?
    let surfaces: [ScheduleSurface]
    let visit: ScheduleVisit?

    enum CodingKeys: String, CodingKey {
        case bookingId = "booking_id"
        case scheduledDate = "scheduled_date"
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
        case arrivalWindowStart = "arrival_window_start"
        case arrivalWindowEnd = "arrival_window_end"
        case status, priority
        case siteAddress = "site_address"
        case siteLatitude = "site_latitude"
        case siteLongitude = "site_longitude"
        case notes
        case internalNotes = "internal_notes"
        case service
        case jobService = "job_service"
        case job, customer, contact, surfaces, visit
    }
}

struct ScheduleService: Codable {
    let serviceId: UUID
    let name: String
    let code: String?

    enum CodingKeys: String, CodingKey {
        case serviceId = "service_id"
        case name, code
    }
}

struct ScheduleJobService: Codable {
    let jobServiceId: UUID
    let status: String
    let sequenceOrder: Int

    enum CodingKeys: String, CodingKey {
        case jobServiceId = "job_service_id"
        case status
        case sequenceOrder = "sequence_order"
    }
}

struct ScheduleJob: Codable {
    let jobId: UUID
    let jobNumber: String
    let status: String
    let priority: String
    let constructionType: String?
    let tearoutRequired: Bool?
    let tearoutNotes: String?
    let plumbingDisconnect: Bool?
    let siteAddressLine1: String?
    let siteAddressLine2: String?
    let siteCity: String?
    let siteState: String?
    let siteZip: String?
    let siteLatitude: Double?
    let siteLongitude: Double?
    let siteContactName: String?
    let siteContactPhone: String?
    let siteAccessNotes: String?
    let specialInstructions: String?
    let totalSqft: Double?
    let numPieces: Int?

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case jobNumber = "job_number"
        case status, priority
        case constructionType = "construction_type"
        case tearoutRequired = "tearout_required"
        case tearoutNotes = "tearout_notes"
        case plumbingDisconnect = "plumbing_disconnect"
        case siteAddressLine1 = "site_address_line1"
        case siteAddressLine2 = "site_address_line2"
        case siteCity = "site_city"
        case siteState = "site_state"
        case siteZip = "site_zip"
        case siteLatitude = "site_latitude"
        case siteLongitude = "site_longitude"
        case siteContactName = "site_contact_name"
        case siteContactPhone = "site_contact_phone"
        case siteAccessNotes = "site_access_notes"
        case specialInstructions = "special_instructions"
        case totalSqft = "total_sqft"
        case numPieces = "num_pieces"
    }

    var fullAddress: String {
        [siteAddressLine1, siteAddressLine2, siteCity, siteState, siteZip]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

struct ScheduleCustomer: Codable {
    let customerId: UUID
    let name: String
    let firstName: String?
    let lastName: String?
    let phone: String?
    let email: String?
    let accountNumber: String?
    let customerType: String?

    enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case name
        case firstName = "first_name"
        case lastName = "last_name"
        case phone, email
        case accountNumber = "account_number"
        case customerType = "customer_type"
    }

    var displayName: String {
        if let first = firstName, let last = lastName, !first.isEmpty {
            return "\(first) \(last)"
        }
        return name
    }
}

struct ScheduleContact: Codable {
    let contactId: UUID
    let firstName: String
    let lastName: String
    let phone: String?
    let mobile: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case contactId = "contact_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case phone, mobile, email
    }

    var fullName: String { "\(firstName) \(lastName)" }
    var bestPhone: String? { mobile ?? phone }
}

struct ScheduleSurface: Codable, Identifiable {
    var id: UUID { surfaceId }

    let surfaceId: UUID
    let name: String?
    let roomName: String?
    let roomQualifier: String?
    let displayOrder: Int?
    let estimatedSqft: Double?
    let estimatedLengthInches: Double?
    let estimatedWidthInches: Double?
    let actualSqft: Double?
    let actualLengthInches: Double?
    let actualWidthInches: Double?
    let templateNotes: String?
    let templatedAt: String?
    let hasBacksplash: Bool?
    let material: ScheduleMaterial?
    let edgeProfile: ScheduleEdgeProfile?
    let backsplashPieces: [ScheduleBacksplash]

    enum CodingKeys: String, CodingKey {
        case surfaceId = "surface_id"
        case name
        case roomName = "room_name"
        case roomQualifier = "room_qualifier"
        case displayOrder = "display_order"
        case estimatedSqft = "estimated_sqft"
        case estimatedLengthInches = "estimated_length_inches"
        case estimatedWidthInches = "estimated_width_inches"
        case actualSqft = "actual_sqft"
        case actualLengthInches = "actual_length_inches"
        case actualWidthInches = "actual_width_inches"
        case templateNotes = "template_notes"
        case templatedAt = "templated_at"
        case hasBacksplash = "has_backsplash"
        case material
        case edgeProfile = "edge_profile"
        case backsplashPieces = "backsplash_pieces"
    }

    var displayName: String {
        let room = roomName ?? ""
        let qualifier = roomQualifier.map { " (\($0))" } ?? ""
        let surfaceName = name ?? "Surface"
        return "\(room)\(qualifier) — \(surfaceName)"
    }

    var isTemplated: Bool { templatedAt != nil }
}

struct ScheduleMaterial: Codable {
    let materialId: UUID
    let name: String
    let manufacturer: String?
    let colorCode: String?

    enum CodingKeys: String, CodingKey {
        case materialId = "material_id"
        case name, manufacturer
        case colorCode = "color_code"
    }

    var displayName: String {
        if let mfr = manufacturer, !mfr.isEmpty {
            return "\(mfr) \(name)"
        }
        return name
    }
}

struct ScheduleEdgeProfile: Codable {
    let edgeProfileId: UUID
    let name: String
    let code: String?

    enum CodingKeys: String, CodingKey {
        case edgeProfileId = "edge_profile_id"
        case name, code
    }
}

struct ScheduleBacksplash: Codable, Identifiable {
    var id: UUID { surfaceBacksplashId }

    let surfaceBacksplashId: UUID
    let displayOrder: Int?
    let heightInches: Double
    let lengthInches: Double
    let finishedEnds: Int
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case surfaceBacksplashId = "surface_backsplash_id"
        case displayOrder = "display_order"
        case heightInches = "height_inches"
        case lengthInches = "length_inches"
        case finishedEnds = "finished_ends"
        case notes
    }
}

struct ScheduleVisit: Codable {
    let visitId: UUID
    let status: String
    let outcome: String?
    let departedAt: String?
    let arrivedAt: String?
    let workStartedAt: String?
    let completedAt: String?
    let fieldNotes: String?
    let signatureRequired: Bool?
    let signatureCaptured: Bool?

    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
        case status, outcome
        case departedAt = "departed_at"
        case arrivedAt = "arrived_at"
        case workStartedAt = "work_started_at"
        case completedAt = "completed_at"
        case fieldNotes = "field_notes"
        case signatureRequired = "signature_required"
        case signatureCaptured = "signature_captured"
    }
}

// MARK: - Checklist Models

struct ChecklistItemResponse: Codable, Identifiable {
    var id: UUID { visitChecklistItemId }

    let visitChecklistItemId: UUID
    let visitChecklistId: UUID
    let templateItemId: UUID?
    let label: String
    let displayOrder: Int
    let section: String?
    let status: String
    let notes: String?
    let checkedAt: String?

    enum CodingKeys: String, CodingKey {
        case visitChecklistItemId = "visit_checklist_item_id"
        case visitChecklistId = "visit_checklist_id"
        case templateItemId = "template_item_id"
        case label
        case displayOrder = "display_order"
        case section, status, notes
        case checkedAt = "checked_at"
    }
}
