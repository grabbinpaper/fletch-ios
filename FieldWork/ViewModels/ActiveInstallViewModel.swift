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

    // Signature
    var signatureMode: SignatureMode = .inPerson
    var signatureName = ""
    var signatureImage: UIImage?
    var signatureLinkSent = false
    var signatureLinkSentAt: Date?

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

        // Create missing statuses for surfaces that don't have one yet
        for surface in booking.surfaces {
            if surfaceStatuses[surface.surfaceId] == nil {
                let status = CachedSurfaceStatus(visitId: visitId, surfaceId: surface.surfaceId)
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

    var ctaLabel: String {
        if allInstalled {
            return "Complete Visit"
        } else if flaggedCount > 0 {
            return "Complete Visit with Issues (\(flaggedCount) flagged)"
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

    func determineOutcome() -> String {
        if allInstalled { return "installed" }
        if flaggedCount > 0 && confirmedCount == totalSurfaceCount { return "partial" }
        return "not_installed"
    }

    @MainActor
    func completeVisit(context: ModelContext) async {
        guard let appState, let visitId = booking.visitId else { return }

        isCompleting = true
        error = nil

        let outcome = determineOutcome()

        do {
            let lat = appState.locationManager.latitude
            let lng = appState.locationManager.longitude

            let params: [String: String] = [
                "p_visit_id": visitId.uuidString,
                "p_worker_id": (appState.staffId ?? UUID()).uuidString,
                "p_lat": lat.map { "\($0)" } ?? "",
                "p_lng": lng.map { "\($0)" } ?? "",
                "p_outcome": outcome,
                "p_notes": completionNotes
            ]
            try await appState.supabaseManager.client
                .rpc("complete_install_visit", params: params)
                .execute()
        } catch {
            // Fall back to local completion for demo
            NSLog("[FieldWork] complete_install_visit RPC failed, completing locally: %@", "\(error)")
        }

        booking.visitStatus = "completed"
        booking.visitCompletedAt = Date()
        booking.visitOutcome = outcome
        try? context.save()

        isCompleting = false
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
        guard let visitId = booking.visitId else {
            // Seed demo checklist items for testing
            seedDemoChecklist()
            return
        }

        Task {
            guard let appState, appState.networkMonitor.isConnected else {
                await MainActor.run {
                    loadChecklistFromCache(visitId: visitId, context: context)
                    if checklistItems.isEmpty { seedDemoChecklist() }
                }
                return
            }

            do {
                struct VisitChecklist: Codable {
                    let visitChecklistId: UUID
                    enum CodingKeys: String, CodingKey {
                        case visitChecklistId = "visit_checklist_id"
                    }
                }

                let checklists: [VisitChecklist] = try await appState.supabaseManager.client
                    .from("visit_checklist")
                    .select("visit_checklist_id")
                    .eq("visit_id", value: visitId.uuidString)
                    .execute()
                    .value

                guard let checklistId = checklists.first?.visitChecklistId else {
                    await MainActor.run { seedDemoChecklist() }
                    return
                }

                let items: [ChecklistItemResponse] = try await appState.supabaseManager.client
                    .from("visit_checklist_item")
                    .select()
                    .eq("visit_checklist_id", value: checklistId.uuidString)
                    .order("display_order")
                    .execute()
                    .value

                await MainActor.run {
                    for item in items {
                        let cached = CachedChecklistItem(from: item)
                        context.insert(cached)
                    }
                    try? context.save()
                    self.checklistItems = items.map { CachedChecklistItem(from: $0) }
                }
            } catch {
                await MainActor.run {
                    loadChecklistFromCache(visitId: visitId, context: context)
                    if checklistItems.isEmpty { seedDemoChecklist() }
                }
            }
        }
    }

    private func loadChecklistFromCache(visitId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<CachedChecklistItem>(
            sortBy: [SortDescriptor(\.displayOrder)]
        )
        checklistItems = (try? context.fetch(descriptor)) ?? []
    }

    /// Seed demo checklist for install visits when no server data available
    private func seedDemoChecklist() {
        let checklistId = UUID()
        let items: [(String, String, String?, Int)] = [
            // (label, fieldType, section, order)
            ("Confirm all pieces unloaded from truck", "pass_fail", "Pre-Install", 1),
            ("Inspect pieces for damage before install", "pass_fail", "Pre-Install", 2),
            ("Verify cabinet/substrate is level", "pass_fail", "Pre-Install", 3),
            ("Confirm plumbing is capped/disconnected", "pass_fail", "Pre-Install", 4),

            ("Seams aligned and bonded properly", "pass_fail", "Install Quality", 5),
            ("Overhangs match spec", "pass_fail", "Install Quality", 6),
            ("Edge profiles match quote", "pass_fail", "Install Quality", 7),
            ("Sink cutout fits appliance", "pass_fail", "Install Quality", 8),
            ("Backsplash installed flush to wall", "pass_fail", "Install Quality", 9),

            ("Plumbing reconnected and tested", "pass_fail", "Post-Install", 10),
            ("Cooktop/appliances reset in place", "pass_fail", "Post-Install", 11),
            ("Surfaces cleaned and polished", "pass_fail", "Post-Install", 12),
            ("Debris removed from site", "pass_fail", "Post-Install", 13),
            ("Customer walkthrough completed", "pass_fail", "Post-Install", 14),

            ("Overall installation quality", "single_select", "Sign-Off", 15),
            ("Customer feedback notes", "text", "Sign-Off", 16),
        ]

        checklistItems = items.map { label, fieldType, section, order in
            let item = CachedChecklistItem(
                itemId: UUID(),
                visitChecklistId: checklistId,
                label: label,
                displayOrder: order,
                section: section,
                fieldType: fieldType
            )
            return item
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
