import Foundation
import SwiftData

// Shared date parsers for RPC response formats
private let iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private let plainDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    return f
}()

/// Parse a datetime string from the RPC (ISO8601 with timezone, e.g. "2026-03-14T09:00:00+00:00")
func parseDatetime(_ string: String) -> Date? {
    iso8601Formatter.date(from: string)
}

/// Parse a plain date string from the RPC (e.g. "2026-03-14")
func parsePlainDate(_ string: String) -> Date? {
    plainDateFormatter.date(from: string) ?? iso8601Formatter.date(from: string)
}

@Model
final class CachedBooking {
    @Attribute(.unique) var bookingId: UUID
    var scheduledDate: Date
    var startDatetime: Date
    var endDatetime: Date
    var status: String
    var priority: String
    var siteAddress: String?
    var siteLatitude: Double?
    var siteLongitude: Double?
    var notes: String?
    var serviceName: String
    var serviceCode: String?
    var serviceId: UUID

    // Denormalized job fields
    var jobId: UUID?
    var jobServiceId: UUID?
    var jobNumber: String?
    var jobStatus: String?
    var jobPriority: String?
    var constructionType: String?
    var tearoutRequired: Bool
    var plumbingDisconnect: Bool
    var siteAddressLine1: String?
    var siteCity: String?
    var siteState: String?
    var siteZip: String?
    var siteContactName: String?
    var siteContactPhone: String?
    var siteAccessNotes: String?
    var specialInstructions: String?

    // Denormalized customer fields
    var customerId: UUID?
    var customerName: String?
    var customerPhone: String?
    var customerEmail: String?
    var accountNumber: String?
    var customerType: String?

    // Contact
    var contactName: String?
    var contactPhone: String?
    var contactEmail: String?

    // Visit state
    var visitId: UUID?
    var visitStatus: String?
    var visitOutcome: String?
    var visitDepartedAt: Date?
    var visitArrivedAt: Date?
    var visitCompletedAt: Date?
    var signatureRequired: Bool
    var signatureCaptured: Bool

    var lastSyncedAt: Date

    @Relationship(deleteRule: .cascade) var surfaces: [CachedSurface]

    init(from booking: ScheduleBooking) {
        self.bookingId = booking.bookingId
        self.scheduledDate = parsePlainDate(booking.scheduledDate) ?? Date()
        self.startDatetime = parseDatetime(booking.startDatetime) ?? Date()
        self.endDatetime = parseDatetime(booking.endDatetime) ?? Date()
        self.status = booking.status
        self.priority = booking.priority
        self.siteAddress = booking.siteAddress
        self.siteLatitude = booking.siteLatitude
        self.siteLongitude = booking.siteLongitude
        self.notes = booking.notes
        self.serviceName = booking.service.name
        self.serviceCode = booking.service.code
        self.serviceId = booking.service.serviceId

        self.jobId = booking.job?.jobId
        self.jobServiceId = booking.jobService?.jobServiceId
        self.jobNumber = booking.job?.jobNumber
        self.jobStatus = booking.job?.status
        self.jobPriority = booking.job?.priority
        self.constructionType = booking.job?.constructionType
        self.tearoutRequired = booking.job?.tearoutRequired ?? false
        self.plumbingDisconnect = booking.job?.plumbingDisconnect ?? false
        self.siteAddressLine1 = booking.job?.siteAddressLine1
        self.siteCity = booking.job?.siteCity
        self.siteState = booking.job?.siteState
        self.siteZip = booking.job?.siteZip
        self.siteContactName = booking.job?.siteContactName
        self.siteContactPhone = booking.job?.siteContactPhone
        self.siteAccessNotes = booking.job?.siteAccessNotes
        self.specialInstructions = booking.job?.specialInstructions

        self.customerId = booking.customer?.customerId
        self.customerName = booking.customer?.displayName
        self.customerPhone = booking.customer?.phone
        self.customerEmail = booking.customer?.email
        self.accountNumber = booking.customer?.accountNumber
        self.customerType = booking.customer?.customerType

        self.contactName = booking.contact?.fullName
        self.contactPhone = booking.contact?.bestPhone
        self.contactEmail = booking.contact?.email

        self.visitId = booking.visit?.visitId
        self.visitStatus = booking.visit?.status
        self.visitOutcome = booking.visit?.outcome
        self.visitDepartedAt = booking.visit?.departedAt.flatMap { parseDatetime($0) }
        self.visitArrivedAt = booking.visit?.arrivedAt.flatMap { parseDatetime($0) }
        self.visitCompletedAt = booking.visit?.completedAt.flatMap { parseDatetime($0) }
        self.signatureRequired = booking.visit?.signatureRequired ?? false
        self.signatureCaptured = booking.visit?.signatureCaptured ?? false

        self.lastSyncedAt = Date()
        self.surfaces = booking.surfaces.map { CachedSurface(from: $0) }
    }

    func update(from booking: ScheduleBooking) {
        self.scheduledDate = parsePlainDate(booking.scheduledDate) ?? self.scheduledDate
        self.startDatetime = parseDatetime(booking.startDatetime) ?? self.startDatetime
        self.endDatetime = parseDatetime(booking.endDatetime) ?? self.endDatetime
        self.status = booking.status
        self.priority = booking.priority
        self.siteAddress = booking.siteAddress
        self.visitId = booking.visit?.visitId
        self.visitStatus = booking.visit?.status
        self.visitOutcome = booking.visit?.outcome
        self.visitDepartedAt = booking.visit?.departedAt.flatMap { parseDatetime($0) }
        self.visitArrivedAt = booking.visit?.arrivedAt.flatMap { parseDatetime($0) }
        self.visitCompletedAt = booking.visit?.completedAt.flatMap { parseDatetime($0) }
        self.signatureCaptured = booking.visit?.signatureCaptured ?? false
        self.lastSyncedAt = Date()
    }

    var fullAddress: String {
        [siteAddressLine1, siteCity, siteState, siteZip]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var surfaceCount: Int { surfaces.count }
    var templatedSurfaceCount: Int { surfaces.filter(\.isTemplated).count }
}

@Model
final class CachedSurface {
    @Attribute(.unique) var surfaceId: UUID
    var name: String
    var roomName: String?
    var roomQualifier: String?
    var displayOrder: Int
    var estimatedSqft: Double?
    var estimatedLengthInches: Double?
    var estimatedWidthInches: Double?
    var actualSqft: Double?
    var actualLengthInches: Double?
    var actualWidthInches: Double?
    var templateNotes: String?
    var isTemplated: Bool
    var hasBacksplash: Bool
    var materialName: String?
    var edgeProfileName: String?

    @Relationship(deleteRule: .cascade) var backsplashPieces: [CachedBacksplash]
    @Relationship var booking: CachedBooking?

    init(from surface: ScheduleSurface) {
        self.surfaceId = surface.surfaceId
        self.name = surface.name ?? "Surface"
        self.roomName = surface.roomName
        self.roomQualifier = surface.roomQualifier
        self.displayOrder = surface.displayOrder ?? 0
        self.estimatedSqft = surface.estimatedSqft
        self.estimatedLengthInches = surface.estimatedLengthInches
        self.estimatedWidthInches = surface.estimatedWidthInches
        self.actualSqft = surface.actualSqft
        self.actualLengthInches = surface.actualLengthInches
        self.actualWidthInches = surface.actualWidthInches
        self.templateNotes = surface.templateNotes
        self.isTemplated = surface.isTemplated
        self.hasBacksplash = surface.hasBacksplash ?? false
        self.materialName = surface.material?.displayName
        self.edgeProfileName = surface.edgeProfile?.name
        self.backsplashPieces = surface.backsplashPieces.map { CachedBacksplash(from: $0) }
    }

    var displayName: String {
        let room = roomName ?? ""
        let qualifier = roomQualifier.map { " (\($0))" } ?? ""
        if room.isEmpty { return name }
        return "\(room)\(qualifier) — \(name)"
    }
}

@Model
final class CachedBacksplash {
    @Attribute(.unique) var surfaceBacksplashId: UUID
    var displayOrder: Int
    var heightInches: Double
    var lengthInches: Double
    var finishedEnds: Int
    var notes: String?

    @Relationship var surface: CachedSurface?

    init(from bs: ScheduleBacksplash) {
        self.surfaceBacksplashId = bs.surfaceBacksplashId
        self.displayOrder = bs.displayOrder ?? 0
        self.heightInches = bs.heightInches
        self.lengthInches = bs.lengthInches
        self.finishedEnds = bs.finishedEnds
        self.notes = bs.notes
    }
}

// MARK: - Visit & Checklist Cache

@Model
final class CachedVisit {
    @Attribute(.unique) var visitId: UUID
    var bookingId: UUID
    var status: String
    var outcome: String?
    var departedAt: Date?
    var arrivedAt: Date?
    var completedAt: Date?

    init(visitId: UUID, bookingId: UUID, status: String) {
        self.visitId = visitId
        self.bookingId = bookingId
        self.status = status
    }
}

@Model
final class CachedChecklistItem {
    @Attribute(.unique) var itemId: UUID
    var visitChecklistId: UUID
    var label: String
    var displayOrder: Int
    var section: String?
    var status: String
    var notes: String?

    init(from item: ChecklistItemResponse) {
        self.itemId = item.visitChecklistItemId
        self.visitChecklistId = item.visitChecklistId
        self.label = item.label
        self.displayOrder = item.displayOrder
        self.section = item.section
        self.status = item.status
        self.notes = item.notes
    }
}

@Model
final class CachedPhoto {
    @Attribute(.unique) var localId: UUID
    var localFilePath: String
    var thumbnailPath: String?
    var caption: String?
    var surfaceId: UUID?
    var jobId: UUID
    var visitId: UUID?
    var capturedAt: Date
    var latitude: Double?
    var longitude: Double?
    var isSynced: Bool
    var hasAnnotations: Bool
    var annotationData: Data?
    var siteConditionKey: String?

    init(
        localFilePath: String,
        thumbnailPath: String? = nil,
        jobId: UUID,
        visitId: UUID?,
        surfaceId: UUID? = nil,
        caption: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        hasAnnotations: Bool = false,
        annotationData: Data? = nil,
        siteConditionKey: String? = nil
    ) {
        self.localId = UUID()
        self.localFilePath = localFilePath
        self.thumbnailPath = thumbnailPath
        self.caption = caption
        self.surfaceId = surfaceId
        self.jobId = jobId
        self.visitId = visitId
        self.capturedAt = Date()
        self.latitude = latitude
        self.longitude = longitude
        self.isSynced = false
        self.hasAnnotations = hasAnnotations
        self.annotationData = annotationData
        self.siteConditionKey = siteConditionKey
    }
}

// MARK: - Site Condition Cache

@Model
final class CachedSiteCondition {
    @Attribute(.unique) var id: UUID
    var visitId: UUID
    var conditionKey: String
    var status: String
    var detailValue: String?
    var notes: String?
    var photoCount: Int
    var assessedAt: Date?
    var isSynced: Bool

    init(visitId: UUID, conditionKey: String) {
        self.id = UUID()
        self.visitId = visitId
        self.conditionKey = conditionKey
        self.status = "no_issue"
        self.photoCount = 0
        self.isSynced = false
    }
}

// MARK: - Sync Operation

@Model
final class SyncOperation {
    @Attribute(.unique) var operationId: UUID
    var operationType: String
    var entityType: String
    var entityId: String
    var payload: Data
    var status: String
    var retryCount: Int
    var lastError: String?
    var createdAt: Date
    var completedAt: Date?

    init(
        operationType: String,
        entityType: String,
        entityId: String,
        payload: Data
    ) {
        self.operationId = UUID()
        self.operationType = operationType
        self.entityType = entityType
        self.entityId = entityId
        self.payload = payload
        self.status = "pending"
        self.retryCount = 0
        self.createdAt = Date()
    }
}
