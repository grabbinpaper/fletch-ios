import Foundation
import SwiftUI
import SwiftData
import UIKit

@Observable
final class ActiveInstallViewModel {
    var booking: CachedBooking
    var selectedTab: InstallTab = .areas
    var surfaceStatuses: [UUID: CachedSurfaceStatus] = [:]
    var photos: [CachedPhoto] = []
    var checklistItems: [CachedChecklistItem] = []
    var isCompleting = false
    var showCompletionSheet = false
    var completionNotes = ""
    var error: String?
    /// What the office got when the visit was finished (shown on the completion sheet).
    var completionResult: CompleteInstallResult?

    /// The shop's issue reasons for install visits (Settings -> Field Operations -> Issue codes).
    var issueReasons: [IssueReasonCode] = IssueReasonCodes.cached

    // Signature
    var signatureMode: SignatureMode = .inPerson
    var signatureName = ""
    var signatureImage: UIImage?
    /// Remote sign-off: how the link goes to the customer when the visit is finished.
    var remoteChannel: SignoffChannel = .sms
    var signatureLinkSent = false
    var signatureLinkSentAt: Date?
    var isSendingLink = false
    var signoffError: String?

    // Site
    var siteNotes = ""
    var accessIssues = false
    var accessIssueNotes = ""
    var tearoutStatus: TearoutStatus = .notApplicable

    /// Auto-save draft manager
    let draftManager = DraftManager()

    private var appState: AppState?

    init(booking: CachedBooking) {
        self.booking = booking
    }

    func configure(appState: AppState) {
        self.appState = appState
        if booking.customerPhone?.isEmpty ?? true, !(booking.customerEmail?.isEmpty ?? true) {
            remoteChannel = .email
        }
    }

    @MainActor
    func loadIssueReasons() async {
        guard let appState else { return }
        issueReasons = await IssueReasonCodes.load(appState: appState)
    }

    func issueReasons(for responsibility: IssueResponsibility) -> [IssueReasonCode] {
        issueReasons.filter { $0.responsibility == responsibility.rawValue }
    }

    func issueReason(id: String?) -> IssueReasonCode? {
        guard let id, let uuid = UUID(uuidString: id) else { return nil }
        return issueReasons.first { $0.id == uuid }
    }

    /// Tabs shown: the Sign tab only when this customer signs off.
    var visibleTabs: [InstallTab] {
        InstallTab.allCases.filter { $0 != .sign || booking.signatureRequired }
    }

    // MARK: - Surface Status Management

    func initializeSurfaceStatuses(context: ModelContext) {
        guard let visitId = booking.visitId else { return }

        // Load existing from cache
        let descriptor = FetchDescriptor<CachedSurfaceStatus>(
            predicate: #Predicate<CachedSurfaceStatus> { $0.visitId == visitId }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        for status in existing {
            surfaceStatuses[status.surfaceId] = status
        }

        // Create missing statuses for surfaces that don't have one yet. A surface installed on an
        // earlier install day starts as installed (multi-day installs carry over).
        for surface in booking.surfaces {
            if surfaceStatuses[surface.surfaceId] == nil {
                let status = CachedSurfaceStatus(visitId: visitId, surfaceId: surface.surfaceId)
                if surface.installStatus == "installed" { status.status = "installed" }
                context.insert(status)
                surfaceStatuses[surface.surfaceId] = status
            }
        }
        try? context.save()
    }

    func status(for surfaceId: UUID) -> CachedSurfaceStatus? {
        surfaceStatuses[surfaceId]
    }

    func setStatus(_ newStatus: String, for surfaceId: UUID, context: ModelContext) {
        guard let surfaceStatus = surfaceStatuses[surfaceId] else { return }
        surfaceStatus.status = newStatus
        if newStatus == "installed" {
            surfaceStatus.responsibility = nil
            surfaceStatus.reasonCode = nil
            surfaceStatus.notes = nil
        } else if surfaceStatus.responsibility == nil {
            surfaceStatus.responsibility = IssueResponsibility.fabricator.rawValue  // what the card shows first
        }
        try? context.save()
        markDraftDirty(context: context)
    }

    func setIssueDetails(
        for surfaceId: UUID,
        responsibility: String,
        reasonCode: String?,
        notes: String?,
        context: ModelContext
    ) {
        guard let surfaceStatus = surfaceStatuses[surfaceId] else { return }
        surfaceStatus.responsibility = responsibility
        surfaceStatus.reasonCode = reasonCode
        surfaceStatus.notes = notes
        try? context.save()
        markDraftDirty(context: context)
    }

    // MARK: - Progress

    var confirmedCount: Int {
        surfaceStatuses.values.filter { $0.status != "pending" }.count
    }

    var totalSurfaceCount: Int {
        booking.surfaces.count
    }

    var surfaceProgress: Double {
        guard totalSurfaceCount > 0 else { return 0 }
        return Double(confirmedCount) / Double(totalSurfaceCount)
    }

    var installedCount: Int {
        surfaceStatuses.values.filter { $0.status == "installed" }.count
    }

    var flaggedCount: Int {
        surfaceStatuses.values.filter { $0.status == "partial" || $0.status == "not_installed" }.count
    }

    var allConfirmed: Bool {
        totalSurfaceCount > 0 && confirmedCount == totalSurfaceCount
    }

    var allInstalled: Bool {
        totalSurfaceCount > 0 && installedCount == totalSurfaceCount
    }

    var unmarkedCount: Int {
        totalSurfaceCount - confirmedCount
    }

    /// Another install day is booked for this job, so unmarked surfaces carry over.
    var moreInstallDays: Bool { booking.moreInstallDays }

    var ctaLabel: String {
        if allInstalled {
            return "Complete Visit"
        } else if flaggedCount > 0 {
            return "Complete Visit with Issues (\(flaggedCount) flagged)"
        } else if moreInstallDays {
            return "Finish Today (\(confirmedCount)/\(totalSurfaceCount))"
        } else {
            return "Complete as Partial (\(confirmedCount)/\(totalSurfaceCount))"
        }
    }

    var ctaColor: Color {
        if allInstalled { return .green }
        if flaggedCount > 0 { return .orange }
        return .orange
    }

    // MARK: - Draft Auto-Save

    func markDraftDirty(context: ModelContext) {
        guard let visitId = booking.visitId else { return }
        draftManager.markDirty(
            visitId: visitId,
            booking: booking,
            checklistItems: [],
            completionNotes: completionNotes,
            appState: appState,
            context: context
        )
    }

    func saveDraftNow(context: ModelContext) {
        guard let visitId = booking.visitId else { return }
        draftManager.saveNow(
            visitId: visitId,
            booking: booking,
            checklistItems: [],
            completionNotes: completionNotes,
            appState: appState,
            context: context
        )
    }

    // MARK: - Photos

    var pendingImage: UIImage?
    var pendingSurfaceId: UUID?
    var pendingCaption: String?
    var pendingCategory: String = "general"
    var showMarkup = false

    var isSiteCapture = false
    var showSiteTagPicker = false
    var pendingTagImage: UIImage?
    var pendingTagAnnotationData: Data?
    var selectedSiteTags: Set<String> = []
    var sitePhotoNote = ""

    func capturePhoto(
        image: UIImage,
        surfaceId: UUID? = nil,
        caption: String? = nil,
        category: String = "general",
        context: ModelContext
    ) {
        pendingImage = image
        pendingSurfaceId = surfaceId
        pendingCaption = caption
        pendingCategory = category
        showMarkup = true
    }

    func savePhoto(
        image: UIImage,
        annotationData: Data?,
        surfaceId: UUID? = nil,
        caption: String? = nil,
        siteConditionKey: String? = nil,
        category: String = "general",
        context: ModelContext
    ) {
        guard let appState, let jobId = booking.jobId else { return }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileId = UUID().uuidString
        let fileName = "\(fileId).jpg"
        let thumbName = "\(fileId)_thumb.jpg"
        let fileURL = documentsURL.appendingPathComponent(fileName)
        let thumbURL = documentsURL.appendingPathComponent(thumbName)

        guard let compressedData = ImageProcessor.compress(image) else { return }
        try? compressedData.write(to: fileURL)

        var thumbPath: String?
        if let thumbData = ImageProcessor.generateThumbnail(image) {
            try? thumbData.write(to: thumbURL)
            thumbPath = thumbURL.path
        }

        let hasAnnotations = annotationData != nil

        let photo = CachedPhoto(
            localFilePath: fileURL.path,
            thumbnailPath: thumbPath,
            jobId: jobId,
            visitId: booking.visitId,
            surfaceId: surfaceId,
            caption: caption,
            latitude: appState.locationManager.latitude,
            longitude: appState.locationManager.longitude,
            hasAnnotations: hasAnnotations,
            annotationData: annotationData,
            siteConditionKey: siteConditionKey,
            category: category
        )
        context.insert(photo)
        photos.append(photo)
        try? context.save()

        let orgId = appState.organizationId?.uuidString ?? "unknown"
        let storagePath = "\(orgId)/\(jobId.uuidString)/\(fileName)"
        let thumbStoragePath = thumbPath != nil ? "\(orgId)/\(jobId.uuidString)/thumbs/\(thumbName)" : nil

        let payload = PhotoUploadPayload(
            localFilePath: fileURL.path,
            storagePath: storagePath,
            fileName: fileName,
            mimeType: "image/jpeg",
            fileSizeBytes: compressedData.count,
            organizationId: appState.organizationId ?? UUID(),
            jobId: jobId,
            visitId: booking.visitId,
            surfaceId: surfaceId,
            uploadedBy: appState.staffId ?? UUID(),
            caption: caption,
            latitude: appState.locationManager.latitude,
            longitude: appState.locationManager.longitude,
            thumbnailLocalPath: thumbPath,
            thumbnailStoragePath: thumbStoragePath,
            hasAnnotations: hasAnnotations,
            siteConditionKey: siteConditionKey,
            category: category
        )
        if let data = try? JSONEncoder().encode(payload) {
            Task {
                await appState.syncEngine.queueOperation(
                    type: "upload_photo",
                    entityType: "photo",
                    entityId: photo.localId.uuidString,
                    payload: data,
                    in: context
                )
            }
        }
    }

    func deferSitePhoto(image: UIImage, annotationData: Data?) {
        pendingTagImage = image
        pendingTagAnnotationData = annotationData
        selectedSiteTags = []
        sitePhotoNote = ""
        showSiteTagPicker = true
    }

    func savePendingSitePhoto(context: ModelContext) {
        guard let image = pendingTagImage else { return }
        let tags = selectedSiteTags.isEmpty ? nil : selectedSiteTags.sorted().joined(separator: ",")
        let caption = sitePhotoNote.isEmpty ? nil : sitePhotoNote

        savePhoto(
            image: image,
            annotationData: pendingTagAnnotationData,
            caption: caption,
            siteConditionKey: tags,
            category: "site",
            context: context
        )

        pendingTagImage = nil
        pendingTagAnnotationData = nil
        selectedSiteTags = []
        sitePhotoNote = ""
        isSiteCapture = false
    }

    // MARK: - Signature

    func saveSignature(image: UIImage, signerName: String, context: ModelContext) {
        guard let appState, let visitId = booking.visitId else { return }

        let fileName = "signature_\(visitId.uuidString).png"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)

        guard let pngData = image.pngData() else { return }
        try? pngData.write(to: fileURL)

        booking.signatureCaptured = true
        signatureImage = image
        signatureName = signerName
        try? context.save()

        let storagePath = "signatures/\(visitId.uuidString)/\(fileName)"
        let payload = SignatureUploadPayload(
            visitId: visitId,
            localFilePath: fileURL.path,
            storagePath: storagePath,
            fileName: fileName,
            signerName: signerName,
            uploadedBy: appState.staffId ?? UUID()
        )
        if let data = try? JSONEncoder().encode(payload) {
            Task {
                await appState.syncEngine.queueOperation(
                    type: "upload_signature",
                    entityType: "signature",
                    entityId: visitId.uuidString,
                    payload: data,
                    in: context
                )
            }
        }
    }

    // MARK: - Completion

    /// Finishes the visit on the server: surface statuses, Site tab, notes, and the customer's name
    /// if they signed on the phone. The server decides what happens to the job (Completed /
    /// Install Incomplete after the last install day) and sends problems to the Exceptions queue.
    @MainActor
    func completeVisit(context: ModelContext) async {
        guard let appState, let visitId = booking.visitId, let staffId = appState.staffId else { return }

        isCompleting = true
        error = nil
        defer { isCompleting = false }

        let surfaces: [CompleteInstallParams.Surface] = booking.surfaces.compactMap { surface in
            guard let st = surfaceStatuses[surface.surfaceId], st.status != "pending" else { return nil }
            let flagged = st.status != "installed"
            return .init(
                surfaceId: surface.surfaceId,
                status: st.status,
                responsibility: flagged ? st.responsibility : nil,
                reasonCodeId: flagged ? st.reasonCode.flatMap(UUID.init(uuidString:)) : nil,
                notes: flagged ? st.notes : nil
            )
        }
        let signedOnPhone = booking.signatureCaptured && !signatureName.trimmingCharacters(in: .whitespaces).isEmpty
        let params = CompleteInstallParams(
            visitId: visitId,
            workerId: staffId,
            surfaces: surfaces,
            site: .init(
                accessIssue: accessIssues,
                accessNotes: accessIssues ? accessIssueNotes : nil,
                tearoutStatus: tearoutStatus.rawValue
            ),
            notes: [siteNotes, completionNotes]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n"),
            signedByName: signedOnPhone ? signatureName : nil,
            lat: appState.locationManager.latitude,
            lng: appState.locationManager.longitude
        )

        let result: CompleteInstallResult
        do {
            result = try await appState.supabaseManager.client
                .rpc("complete_install_visit", params: params)
                .execute()
                .value
        } catch {
            // Only complete once the office has it.
            self.error = "Couldn't complete the install visit: \(error.localizedDescription)"
            return
        }

        guard result.success else {
            let reasons = (result.blockers ?? []).map { b in
                [b.targetLabel, b.message].compactMap { $0 }.joined(separator: ": ")
            }
            self.error = reasons.isEmpty ? "The visit couldn't be completed." : reasons.joined(separator: "\n")
            return
        }

        booking.visitStatus = "completed"
        booking.visitCompletedAt = Date()
        booking.visitOutcome = result.outcome
        if let jobStatus = result.jobStatus { booking.jobStatus = jobStatus }
        try? context.save()
        completionResult = result

        // Remote sign-off: send the link now that the visit is finished.
        if result.signaturePending == true && signatureMode == .remote {
            await sendSignoffLink()
        }
    }

    /// Texts or emails the customer's sign-off link (again, after the first time). The website
    /// reuses the open link, or makes a new one if it expired.
    @MainActor
    func sendSignoffLink() async {
        guard let appState, let visitId = booking.visitId else { return }
        let address = (remoteChannel == .sms ? booking.customerPhone : booking.customerEmail) ?? ""
        isSendingLink = true
        signoffError = nil
        defer { isSendingLink = false }
        do {
            try await FieldworkWebAPI.sendSignoff(
                visitId: visitId, channel: remoteChannel, address: address,
                name: booking.customerName, appState: appState)
            signatureLinkSent = true
            signatureLinkSentAt = Date()
        } catch {
            signoffError = error.localizedDescription
        }
    }

    func loadPhotos(context: ModelContext) {
        guard let jobId = booking.jobId else { return }
        let descriptor = FetchDescriptor<CachedPhoto>(
            predicate: #Predicate<CachedPhoto> { $0.jobId == jobId },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        photos = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Checklist

    func loadChecklist(context: ModelContext) {
        guard let appState, let visitId = booking.visitId else { return }
        Task { @MainActor in
            checklistItems = await CachedChecklistItem.load(visitId: visitId, appState: appState, context: context)
        }
    }

    func updateChecklistItem(
        _ item: CachedChecklistItem,
        status: String,
        notes: String? = nil,
        responseValue: String? = nil,
        context: ModelContext
    ) {
        item.status = status
        if let notes { item.notes = notes }
        if let responseValue { item.responseValue = responseValue }
        try? context.save()

        markDraftDirty(context: context)

        guard let appState else { return }
        let payload = ChecklistItemPayload(
            itemId: item.itemId,
            status: status,
            notes: item.notes,
            checkedAt: Date(),
            checkedBy: appState.staffId,
            responseValue: item.responseValue,
            photoCount: item.photoCount
        )
        if let data = try? JSONEncoder().encode(payload) {
            Task {
                await appState.syncEngine.queueOperation(
                    type: "update_checklist_item",
                    entityType: "checklist_item",
                    entityId: item.itemId.uuidString,
                    payload: data,
                    in: context
                )
            }
        }
    }
}

// MARK: - Enums

enum InstallTab: String, CaseIterable {
    case areas = "Surfaces"
    case site = "Site"
    case photos = "Photos"
    case checklist = "Check"
    case sign = "Sign"
}

enum SignatureMode: String {
    case inPerson = "in_person"
    case remote = "remote"
}

enum SignoffChannel: String {
    case sms
    case email
}

// MARK: - complete_install_visit

struct CompleteInstallParams: Encodable {
    struct Surface: Encodable {
        let surfaceId: UUID
        let status: String
        let responsibility: String?
        let reasonCodeId: UUID?
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case surfaceId = "surface_id"
            case status, responsibility
            case reasonCodeId = "reason_code_id"
            case notes
        }
    }

    struct Site: Encodable {
        let accessIssue: Bool
        let accessNotes: String?
        let tearoutStatus: String

        enum CodingKeys: String, CodingKey {
            case accessIssue = "access_issue"
            case accessNotes = "access_notes"
            case tearoutStatus = "tearout_status"
        }
    }

    let visitId: UUID
    let workerId: UUID
    let surfaces: [Surface]
    let site: Site
    let notes: String
    let signedByName: String?
    let lat: Double?
    let lng: Double?

    enum CodingKeys: String, CodingKey {
        case visitId = "p_visit_id"
        case workerId = "p_worker_id"
        case surfaces = "p_surfaces"
        case site = "p_site"
        case notes = "p_notes"
        case signedByName = "p_signed_by_name"
        case lat = "p_lat"
        case lng = "p_lng"
    }
}

struct CompleteInstallResult: Decodable {
    struct Blocker: Decodable {
        let message: String
        let targetLabel: String?
        enum CodingKeys: String, CodingKey {
            case message
            case targetLabel = "target_label"
        }
    }

    let success: Bool
    let blockers: [Blocker]?
    let outcome: String?
    let jobStatus: String?
    let lastInstallDay: Bool?
    let issuesCreated: Int?
    let signaturePending: Bool?

    enum CodingKeys: String, CodingKey {
        case success, blockers, outcome
        case jobStatus = "job_status"
        case lastInstallDay = "last_install_day"
        case issuesCreated = "issues_created"
        case signaturePending = "signature_pending"
    }
}

enum TearoutStatus: String, CaseIterable {
    case complete = "complete"
    case incomplete = "incomplete"
    case notApplicable = "not_applicable"

    var label: String {
        switch self {
        case .complete: return "Complete"
        case .incomplete: return "Incomplete"
        case .notApplicable: return "N/A"
        }
    }
}
