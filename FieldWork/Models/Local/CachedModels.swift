import Foundation
import SwiftData
import Supabase

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
final class CachedBooking: Hashable {
    static func == (lhs: CachedBooking, rhs: CachedBooking) -> Bool {
        lhs.bookingId == rhs.bookingId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bookingId)
    }
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
    var visitTypeCode: String?
    var moreInstallDays: Bool = false

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
    var salespersonName: String?
    var salespersonPhone: String?
    var salespersonEmail: String?

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

    // Travel tracking
    var visitDepartureLat: Double?
    var visitDepartureLng: Double?
    var startingAddress: String?
    var travelMiles: Double?
    var travelTimeMinutes: Int?

    var lastSyncedAt: Date

    @Relationship(deleteRule: .cascade) var surfaces: [CachedSurface]
    @Relationship(deleteRule: .cascade) var measurements: [CachedMeasurement]

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
        self.visitTypeCode = booking.service.visitTypeCode
        self.moreInstallDays = booking.service.moreInstallDays ?? false

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
        self.salespersonName = booking.job?.salespersonName
        self.salespersonPhone = booking.job?.salespersonPhone
        self.salespersonEmail = booking.job?.salespersonEmail

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
        self.signatureRequired = booking.signatureRequired
        self.signatureCaptured = booking.visit?.signatureCaptured ?? false

        self.startingAddress = booking.visit?.startingAddress
        self.travelMiles = booking.visit?.calculatedMiles
        self.travelTimeMinutes = booking.visit?.travelTimeMinutes

        self.lastSyncedAt = Date()
        self.surfaces = booking.surfaces.map { CachedSurface(from: $0) }

        if let visitId = booking.visit?.visitId,
           let remoteMeasurements = booking.visit?.measurements {
            self.measurements = remoteMeasurements.map { rm in
                let m = CachedMeasurement(from: rm, visitId: visitId)
                if let remoteBMs = rm.backsplashMeasurements {
                    m.backsplashMeasurements = remoteBMs.map {
                        CachedBacksplashMeasurement(
                            backsplashMeasurementId: $0.backsplashMeasurementId,
                            visitId: visitId,
                            measurementId: rm.measurementId,
                            surfaceBacksplashId: $0.surfaceBacksplashId,
                            location: $0.location,
                            quotedHeightIn: $0.quotedHeightIn,
                            quotedLengthIn: $0.quotedLengthIn,
                            actualHeightIn: $0.actualHeightIn,
                            actualLengthIn: $0.actualLengthIn,
                            finishedEnds: $0.finishedEnds,
                            source: $0.source,
                            notes: $0.notes
                        )
                    }
                }
                return m
            }
        } else {
            self.measurements = []
        }
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
        self.visitTypeCode = booking.service.visitTypeCode
        self.moreInstallDays = booking.service.moreInstallDays ?? false
        self.jobStatus = booking.job?.status ?? self.jobStatus
        self.signatureRequired = booking.signatureRequired
        self.signatureCaptured = booking.visit?.signatureCaptured ?? false
        // Surfaces: refresh what an earlier install day left on each one, and add any this booking
        // doesn't have yet (e.g. it was cached before the office added them). Nothing is removed here,
        // and measured values stay as the tech left them until the visit syncs.
        let cachedById = Dictionary(surfaces.map { ($0.surfaceId, $0) }, uniquingKeysWith: { a, _ in a })
        for remote in booking.surfaces {
            if let cached = cachedById[remote.surfaceId] {
                cached.installStatus = remote.installStatus
            } else {
                surfaces.append(CachedSurface(from: remote))
            }
        }
        self.startingAddress = booking.visit?.startingAddress ?? self.startingAddress
        self.travelMiles = booking.visit?.calculatedMiles ?? self.travelMiles
        self.travelTimeMinutes = booking.visit?.travelTimeMinutes ?? self.travelTimeMinutes
        self.salespersonName = booking.job?.salespersonName ?? self.salespersonName
        self.salespersonPhone = booking.job?.salespersonPhone ?? self.salespersonPhone
        self.salespersonEmail = booking.job?.salespersonEmail ?? self.salespersonEmail
        self.lastSyncedAt = Date()

        // Sync measurements from remote
        if let visitId = booking.visit?.visitId,
           let remoteMeasurements = booking.visit?.measurements {
            let existingById = Dictionary(uniqueKeysWithValues: measurements.map { ($0.measurementId, $0) })
            for remote in remoteMeasurements {
                if let existing = existingById[remote.measurementId] {
                    existing.update(from: remote)
                } else {
                    let m = CachedMeasurement(from: remote, visitId: visitId)
                    if let remoteBMs = remote.backsplashMeasurements {
                        m.backsplashMeasurements = remoteBMs.map {
                            CachedBacksplashMeasurement(
                                backsplashMeasurementId: $0.backsplashMeasurementId,
                                visitId: visitId,
                                measurementId: remote.measurementId,
                                surfaceBacksplashId: $0.surfaceBacksplashId,
                                location: $0.location,
                                quotedHeightIn: $0.quotedHeightIn,
                                quotedLengthIn: $0.quotedLengthIn,
                                actualHeightIn: $0.actualHeightIn,
                                actualLengthIn: $0.actualLengthIn,
                                finishedEnds: $0.finishedEnds,
                                source: $0.source,
                                notes: $0.notes
                            )
                        }
                    }
                    measurements.append(m)
                }
            }
        }
    }

    /// The service's visit type decides it (set per shop in Settings), never the service's name.
    var isInstallVisit: Bool { visitTypeCode == "INST" }

    var fullAddress: String {
        [siteAddressLine1, siteCity, siteState, siteZip]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var surfaceCount: Int { surfaces.count }
    var templatedSurfaceCount: Int { surfaces.filter(\.isTemplated).count }
    var roomCount: Int {
        Set(surfaces.compactMap(\.roomName)).count
    }

    func measurement(for surfaceId: UUID) -> CachedMeasurement? {
        measurements.first { $0.surfaceId == surfaceId }
    }
}

@Model
final class CachedSurface {
    /// Not unique: each booking keeps its own copy of a job's surfaces, so a template visit and
    /// one or more install days on the same job can all be on the phone at once.
    var surfaceId: UUID
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
    /// Install visits: status from an earlier, finished install day (installed / partial / not_installed).
    var installStatus: String?

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
        self.installStatus = surface.installStatus
        self.backsplashPieces = surface.backsplashPieces.map { CachedBacksplash(from: $0) }
    }

    /// Creates a surface record for a field-added surface
    init(fieldAdded surfaceId: UUID, name: String, roomName: String?, displayOrder: Int) {
        self.surfaceId = surfaceId
        self.name = name
        self.roomName = roomName
        self.roomQualifier = nil
        self.displayOrder = displayOrder
        self.estimatedSqft = nil
        self.estimatedLengthInches = nil
        self.estimatedWidthInches = nil
        self.actualSqft = nil
        self.actualLengthInches = nil
        self.actualWidthInches = nil
        self.templateNotes = nil
        self.isTemplated = false
        self.hasBacksplash = false
        self.materialName = nil
        self.edgeProfileName = nil
        self.backsplashPieces = []
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
    /// Not unique, for the same reason as `CachedSurface.surfaceId`.
    var surfaceBacksplashId: UUID
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
    var visitId: UUID?
    var visitChecklistId: UUID
    var label: String
    var displayOrder: Int
    var section: String?
    var status: String
    var notes: String?
    var fieldType: String = "pass_fail"
    var responseValue: String?
    var requiresPhoto: Bool = false
    var photoCount: Int = 0

    init(from item: ChecklistItemResponse, visitId: UUID) {
        self.itemId = item.visitChecklistItemId
        self.visitId = visitId
        self.visitChecklistId = item.visitChecklistId
        self.label = item.label
        self.displayOrder = item.displayOrder
        self.section = item.section
        self.status = item.status
        self.notes = item.notes
        self.fieldType = item.fieldType ?? "pass_fail"
        self.responseValue = item.responseValue
        self.requiresPhoto = item.requiresPhoto ?? false
        self.photoCount = item.photoCount ?? 0
    }

}

// MARK: - Checklist loading (template and install visits)

extension CachedChecklistItem {
    /// This visit's checklist items. Online: fetched from the server; items the phone already has
    /// keep their local answers (changes are queued to sync). Offline or on error: the phone's copy.
    @MainActor
    static func load(visitId: UUID, appState: AppState, context: ModelContext) async -> [CachedChecklistItem] {
        if appState.networkMonitor.isConnected {
            do {
                struct VisitChecklist: Codable {
                    let visitChecklistId: UUID
                    enum CodingKeys: String, CodingKey { case visitChecklistId = "visit_checklist_id" }
                }
                let client = appState.supabaseManager.client
                let checklists: [VisitChecklist] = try await client
                    .from("visit_checklist")
                    .select("visit_checklist_id")
                    .eq("visit_id", value: visitId.uuidString)
                    .execute()
                    .value
                if let checklistId = checklists.first?.visitChecklistId {
                    let items: [ChecklistItemResponse] = try await client
                        .from("visit_checklist_item")
                        .select()
                        .eq("visit_checklist_id", value: checklistId.uuidString)
                        .order("display_order")
                        .execute()
                        .value
                    let have = Dictionary(
                        cached(visitId: visitId, context: context).map { ($0.itemId, $0) },
                        uniquingKeysWith: { a, _ in a })
                    for item in items where have[item.visitChecklistItemId] == nil {
                        context.insert(CachedChecklistItem(from: item, visitId: visitId))
                    }
                    try? context.save()
                }
            } catch {
                // fall through to what the phone has
            }
        }
        return cached(visitId: visitId, context: context)
    }

    @MainActor
    private static func cached(visitId: UUID, context: ModelContext) -> [CachedChecklistItem] {
        let descriptor = FetchDescriptor<CachedChecklistItem>(
            predicate: #Predicate<CachedChecklistItem> { $0.visitId == visitId },
            sortBy: [SortDescriptor(\.displayOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

/// Photos and signatures are saved flat in the app's Documents folder, but iOS moves that folder
/// when the app is reinstalled or updated, so a full path saved earlier goes stale (photos vanish,
/// queued uploads fail with "file not found"). Re-point a saved path at today's Documents folder.
func documentsPath(for storedPath: String) -> String {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documentsURL.appendingPathComponent((storedPath as NSString).lastPathComponent).path
}

extension CachedPhoto {
    var fileOnDisk: String { documentsPath(for: localFilePath) }
    var thumbnailOnDisk: String? { thumbnailPath.map { documentsPath(for: $0) } }
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
    var category: String = "general"

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
        siteConditionKey: String? = nil,
        category: String = "general"
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
        self.category = category
        self.siteConditionKey = siteConditionKey
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
