import Foundation
import SwiftData
import UIKit

@Observable
final class ActiveVisitViewModel {
    var booking: CachedBooking
    var selectedTab: VisitTab = .measurements
    var checklistItems: [CachedChecklistItem] = []
    var photos: [CachedPhoto] = []
    var isCompleting = false
    var showCompletionSheet = false
    var showPartialSheet = false
    var completionNotes = ""
    var error: String?

    // Completion validation
    var completionBlockers: [CompletionBlocker] = []
    var skippedSurfaceInfo: [SkippedSurfaceInfo] = []
    var requiresSignature = false
    var isValidating = false
    var signaturePending = false
    /// The visit was finished unfinished (partial) and this customer signs off, so no sign-off
    /// was asked for (server: `signature_not_allowed`).
    var signoffWithheld = false
    var edgeProfiles: [EdgeProfileOption] = []
    var showAddSurface = false

    /// Auto-save draft manager
    let draftManager = DraftManager()

    private var appState: AppState?

    init(booking: CachedBooking) {
        self.booking = booking
    }

    func configure(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Draft Auto-Save

    /// Notify the draft manager that visit state changed
    func markDraftDirty(context: ModelContext) {
        guard let visitId = booking.visitId else { return }
        draftManager.markDirty(
            visitId: visitId,
            booking: booking,
            checklistItems: checklistItems,
            completionNotes: completionNotes,
            appState: appState,
            context: context
        )
    }

    /// Force immediate draft save (e.g. on app background)
    func saveDraftNow(context: ModelContext) {
        guard let visitId = booking.visitId else { return }
        draftManager.saveNow(
            visitId: visitId,
            booking: booking,
            checklistItems: checklistItems,
            completionNotes: completionNotes,
            appState: appState,
            context: context
        )
    }

    // MARK: - Measurements

    /// Debounce tasks keyed by measurement ID — cancel + restart on each input
    private var debounceTasks: [UUID: Task<Void, Never>] = [:]

    var measurementProgress: Double {
        let ms = booking.measurements
        guard !ms.isEmpty else { return 0 }
        let measured = ms.filter(\.isMeasured).count
        return Double(measured) / Double(ms.count)
    }

    var measuredCount: Int { booking.measurements.filter(\.isMeasured).count }
    var totalMeasurementCount: Int { booking.measurements.count }

    var availableRooms: [RoomInfo] {
        var seen = Set<String>()
        var rooms: [RoomInfo] = []
        for surface in booking.surfaces {
            if let name = surface.roomName, !name.isEmpty, !seen.contains(name) {
                seen.insert(name)
                rooms.append(RoomInfo(id: UUID(), name: name))
            }
        }
        return rooms
    }

    func saveMeasurement(_ measurement: CachedMeasurement, context: ModelContext) {
        // Compute derived fields
        if let l = measurement.actualLengthIn, let w = measurement.actualWidthIn {
            measurement.actualSqft = (l * w) / 144.0
        } else {
            measurement.actualSqft = nil
        }

        if measurement.status != "skipped" && measurement.isMeasured {
            measurement.status = "measured"
        }

        // Local save immediately (crash safety)
        try? context.save()

        // Debounced remote sync (2s)
        scheduleMeasurementSync(measurement: measurement, context: context)

        // Auto-save draft
        markDraftDirty(context: context)
    }

    func loadEdgeProfiles() {
        guard edgeProfiles.isEmpty, let appState else { return }
        Task {
            do {
                struct EP: Codable {
                    let edgeProfileId: UUID
                    let name: String
                    let code: String?
                    enum CodingKeys: String, CodingKey {
                        case edgeProfileId = "edge_profile_id"
                        case name, code
                    }
                }
                let rows: [EP] = try await appState.supabaseManager.client
                    .from("edge_profile")
                    .select("edge_profile_id, name, code")
                    .order("name")
                    .execute()
                    .value
                await MainActor.run {
                    self.edgeProfiles = rows.map {
                        EdgeProfileOption(id: $0.edgeProfileId, name: $0.name, code: $0.code)
                    }
                }
            } catch {
                print("Failed to load edge profiles: \(error)")
            }
        }
    }

    @MainActor
    func addFieldSurface(name: String, roomName: String?, context: ModelContext) async {
        guard let appState, let visitId = booking.visitId, let jobId = booking.jobId,
              let orgId = appState.organizationId else {
            error = "Unable to add surface"
            return
        }

        var params: [String: String] = [
            "p_visit_id": visitId.uuidString,
            "p_job_id": jobId.uuidString,
            "p_org_id": orgId.uuidString,
            "p_name": name
        ]
        if let roomName, !roomName.isEmpty {
            params["p_room_name"] = roomName
        }

        do {
            let response = try await appState.supabaseManager.client
                .rpc("add_field_surface", params: params)
                .execute()

            struct AddResult: Codable {
                let surface_id: UUID
                let measurement_id: UUID
            }
            let result = try JSONDecoder().decode(AddResult.self, from: response.data)

            let displayOrder = (booking.surfaces.map(\.displayOrder).max() ?? 0) + 1
            let newSurface = CachedSurface(
                fieldAdded: result.surface_id,
                name: name,
                roomName: roomName,
                displayOrder: displayOrder
            )
            let newMeasurement = CachedMeasurement(
                fieldAdded: result.measurement_id,
                visitId: visitId,
                surfaceId: result.surface_id
            )

            context.insert(newSurface)
            context.insert(newMeasurement)
            booking.surfaces.append(newSurface)
            booking.measurements.append(newMeasurement)
            try? context.save()
        } catch {
            self.error = "Failed to add surface: \(error.localizedDescription)"
        }
    }

    // MARK: - Cutouts

    func addCutout(data: CutoutFormData, measurement: CachedMeasurement, context: ModelContext) {
        let cutout = CachedCutout(
            visitId: measurement.visitId,
            measurementId: measurement.measurementId,
            cutoutType: data.cutoutType,
            source: "field",
            make: data.make,
            modelName: data.modelName,
            sinkInstallType: data.sinkInstallType,
            faucetHoles: data.faucetHoles,
            bringToShop: data.bringToShop,
            cooktopOnsite: data.cooktopOnsite,
            count: data.count,
            locationNote: data.locationNote
        )

        context.insert(cutout)
        measurement.cutouts.append(cutout)
        try? context.save()

        // Auto-save draft
        markDraftDirty(context: context)

        guard let appState else { return }
        let payload = CutoutInsertPayload(
            cutoutId: cutout.cutoutId,
            visitId: cutout.visitId,
            measurementId: cutout.measurementId,
            cutoutType: cutout.cutoutType,
            source: cutout.source,
            make: cutout.make,
            modelName: cutout.modelName,
            sinkInstallType: cutout.sinkInstallType,
            faucetHoles: cutout.faucetHoles,
            bringToShop: cutout.bringToShop,
            cooktopOnsite: cutout.cooktopOnsite,
            count: cutout.count,
            locationNote: cutout.locationNote,
            changedFromQuote: cutout.changedFromQuote
        )
        if let encoded = try? JSONEncoder().encode(payload) {
            Task {
                await appState.syncEngine.queueOperation(
                    type: "insert_cutout",
                    entityType: "visit_cutout",
                    entityId: cutout.cutoutId.uuidString,
                    payload: encoded,
                    in: context
                )
            }
        }
    }

    // MARK: - Quoted sinks (sink & faucet sheet)

    /// Has this quoted sink got an evidence photo of this kind (on the phone, or already at the office)?
    func hasEvidencePhoto(_ cutout: CachedCutout, category: String) -> Bool {
        cutout.serverPhotoCategories.contains(category)
            || photos.contains { $0.cutoutId == cutout.cutoutId && $0.category == category }
    }

    /// An evidence photo for a quoted sink: straight from the camera, no markup, tied to the sink
    /// (not to the surface, so it doesn't count as a surface photo).
    func saveEvidencePhoto(_ image: UIImage, cutout: CachedCutout, category: String, context: ModelContext) {
        savePhoto(image: image, annotationData: nil,
                  caption: category == "sink_label" ? "Sink box label / model number" : "Faucet or its spec sheet",
                  category: category, cutoutId: cutout.cutoutId, context: context)
    }

    /// Saves the tech's check of a quoted sink: on the phone now, to the office when there's signal.
    /// Recorded with when and where; the office records who and works out what differs.
    func saveSinkCheck(_ cutout: CachedCutout, check: SinkCheck, note: String?, context: ModelContext) {
        cutout.make = check.make
        cutout.modelName = check.model
        cutout.sinkInstallType = check.mount
        cutout.faucetMake = check.faucetMake
        cutout.faucetModel = check.faucetModel
        cutout.faucetHoles = check.faucetHoles
        cutout.holes = check.holes
        cutout.measuredCutoutWidth = check.measuredWidth
        cutout.measuredCutoutDepth = check.measuredDepth
        cutout.sinkOnSite = check.sinkOnSite
        cutout.faucetOnSite = check.faucetOnSite
        cutout.bringToShop = check.sinkOnSite == false
        cutout.locationNote = note
        cutout.checkedAt = Date()
        if let q = cutout.quoted {
            cutout.differences = check.differences(from: q)
            cutout.changedFromQuote = !cutout.differences.isEmpty
        }
        try? context.save()
        markDraftDirty(context: context)

        guard let appState, let checkedAt = cutout.checkedAt else { return }
        let payload = CutoutCheckPayload(
            cutoutId: cutout.cutoutId, make: check.make, model: check.model, mount: check.mount,
            faucetMake: check.faucetMake, faucetModel: check.faucetModel, faucetHoles: check.faucetHoles,
            holes: check.holes, measuredWidth: check.measuredWidth, measuredDepth: check.measuredDepth,
            sinkOnSite: check.sinkOnSite, faucetOnSite: check.faucetOnSite, note: note, checkedAt: checkedAt,
            latitude: appState.locationManager.latitude, longitude: appState.locationManager.longitude
        )
        if let encoded = try? JSONEncoder().encode(payload) {
            Task {
                await appState.syncEngine.queueOperation(
                    type: "update_cutout_check",
                    entityType: "visit_cutout",
                    entityId: cutout.cutoutId.uuidString,
                    payload: encoded,
                    in: context
                )
            }
        }
    }

    // MARK: - Backsplash Measurements

    /// A splash piece's size or finished ends changed: save on the phone now, send it to the
    /// server a moment after the tech stops typing (one update, not one per keystroke).
    func saveBacksplash(_ bm: CachedBacksplashMeasurement, context: ModelContext) {
        try? context.save()
        markDraftDirty(context: context)

        let id = bm.backsplashMeasurementId
        debounceTasks[id]?.cancel()
        debounceTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self, let appState = self.appState else { return }
            let payload = BacksplashUpdatePayload(
                backsplashMeasurementId: bm.backsplashMeasurementId,
                actualHeightIn: bm.actualHeightIn,
                actualLengthIn: bm.actualLengthIn,
                finishedEnds: bm.finishedEnds,
                notes: bm.notes
            )
            guard let encoded = try? JSONEncoder().encode(payload) else { return }
            await appState.syncEngine.queueOperation(
                type: "update_backsplash_measurement",
                entityType: "visit_backsplash_measurement",
                entityId: bm.backsplashMeasurementId.uuidString,
                payload: encoded,
                in: context
            )
        }
    }

    func addBacksplash(data: BacksplashFormData, measurement: CachedMeasurement, context: ModelContext) {
        let bm = CachedBacksplashMeasurement(
            visitId: measurement.visitId,
            measurementId: measurement.measurementId,
            location: data.location,
            actualHeightIn: data.heightIn,
            actualLengthIn: data.lengthIn,
            source: "field"
        )

        context.insert(bm)
        measurement.backsplashMeasurements.append(bm)
        try? context.save()

        markDraftDirty(context: context)

        guard let appState else { return }
        let payload = BacksplashInsertPayload(
            backsplashMeasurementId: bm.backsplashMeasurementId,
            visitId: bm.visitId,
            measurementId: bm.measurementId,
            surfaceBacksplashId: nil,
            location: bm.location,
            quotedHeightIn: nil,
            quotedLengthIn: nil,
            actualHeightIn: bm.actualHeightIn,
            actualLengthIn: bm.actualLengthIn,
            finishedEnds: bm.finishedEnds,
            source: bm.source,
            notes: bm.notes
        )
        if let encoded = try? JSONEncoder().encode(payload) {
            Task {
                await appState.syncEngine.queueOperation(
                    type: "insert_backsplash_measurement",
                    entityType: "visit_backsplash_measurement",
                    entityId: bm.backsplashMeasurementId.uuidString,
                    payload: encoded,
                    in: context
                )
            }
        }
    }

    func removeBacksplash(_ bm: CachedBacksplashMeasurement, context: ModelContext) {
        let bmId = bm.backsplashMeasurementId

        if let measurement = bm.measurement {
            measurement.backsplashMeasurements.removeAll { $0.backsplashMeasurementId == bmId }
        }

        context.delete(bm)
        try? context.save()

        guard let appState else { return }
        let payload = BacksplashDeletePayload(backsplashMeasurementId: bmId)
        if let encoded = try? JSONEncoder().encode(payload) {
            Task {
                await appState.syncEngine.queueOperation(
                    type: "delete_backsplash_measurement",
                    entityType: "visit_backsplash_measurement",
                    entityId: bmId.uuidString,
                    payload: encoded,
                    in: context
                )
            }
        }
    }

    func removeCutout(_ cutout: CachedCutout, context: ModelContext) {
        let cutoutId = cutout.cutoutId

        if let measurement = cutout.measurement {
            measurement.cutouts.removeAll { $0.cutoutId == cutoutId }
        }

        context.delete(cutout)
        try? context.save()

        guard let appState else { return }
        let payload = CutoutDeletePayload(cutoutId: cutoutId)
        if let encoded = try? JSONEncoder().encode(payload) {
            Task {
                await appState.syncEngine.queueOperation(
                    type: "delete_cutout",
                    entityType: "visit_cutout",
                    entityId: cutoutId.uuidString,
                    payload: encoded,
                    in: context
                )
            }
        }
    }

    private func scheduleMeasurementSync(measurement: CachedMeasurement, context: ModelContext) {
        let id = measurement.measurementId
        debounceTasks[id]?.cancel()
        debounceTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.syncMeasurement(measurement: measurement, context: context)
        }
    }

    @MainActor
    private func syncMeasurement(measurement: CachedMeasurement, context: ModelContext) {
        guard let appState else { return }
        let payload = VisitMeasurementPayload(
            measurementId: measurement.measurementId,
            actualLengthIn: measurement.actualLengthIn,
            actualWidthIn: measurement.actualWidthIn,
            actualSqft: measurement.actualSqft,
            edgeProfileId: measurement.edgeProfileId,
            edgeChanged: measurement.edgeChanged,
            overhangDepthIn: measurement.overhangDepthIn,
            backsplashIncluded: measurement.backsplashIncluded,
            backsplashHeightIn: measurement.backsplashHeightIn,
            seamLocationsJson: measurement.seamLocationsJson,
            finishedEnds: measurement.finishedEnds,
            finishedEdges: measurement.finishedEdges,
            templateNotes: measurement.templateNotes,
            status: measurement.status,
            skipReason: measurement.skipReason
        )
        if let data = try? JSONEncoder().encode(payload) {
            Task {
                await appState.syncEngine.queueOperation(
                    type: "update_visit_measurement",
                    entityType: "visit_surface_measurement",
                    entityId: measurement.measurementId.uuidString,
                    payload: data,
                    in: context
                )
            }
        }
    }

    // MARK: - Photos

    /// Pending image awaiting markup decision
    var pendingImage: UIImage?
    var pendingSurfaceId: UUID?
    var pendingCaption: String?
    var pendingCategory: String = "general"
    var showMarkup = false

    /// Site photo tagging flow
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
        // Store pending image and show markup sheet
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
        cutoutId: UUID? = nil,
        context: ModelContext
    ) {
        guard let appState, let jobId = booking.jobId else { return }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileId = UUID().uuidString
        let fileName = "\(fileId).jpg"
        let thumbName = "\(fileId)_thumb.jpg"
        let fileURL = documentsURL.appendingPathComponent(fileName)
        let thumbURL = documentsURL.appendingPathComponent(thumbName)

        // Compress image (1200px longest edge, 72% quality → ~150-300KB)
        guard let compressedData = ImageProcessor.compress(image) else { return }
        try? compressedData.write(to: fileURL)

        // Generate thumbnail (200px square → ~10-20KB)
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
        photo.cutoutId = cutoutId
        context.insert(photo)
        photos.append(photo)
        try? context.save()

        // Queue upload
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
            category: category,
            cutoutId: cutoutId
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

    // MARK: - Site Photo Tagging

    /// Called after markup completes for a site capture — defers save until tags are picked
    func deferSitePhoto(image: UIImage, annotationData: Data?) {
        pendingTagImage = image
        pendingTagAnnotationData = annotationData
        selectedSiteTags = []
        sitePhotoNote = ""
        showSiteTagPicker = true
    }

    /// Saves the deferred site photo with selected tags and note
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

    func cancelPendingSitePhoto() {
        pendingTagImage = nil
        pendingTagAnnotationData = nil
        selectedSiteTags = []
        sitePhotoNote = ""
        isSiteCapture = false
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

        // Auto-save draft
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

    // MARK: - Completion

    var isAllMeasured: Bool {
        !booking.measurements.isEmpty && booking.measurements.allSatisfy(\.isMeasured)
    }

    var isPartial: Bool {
        !booking.measurements.isEmpty && !isAllMeasured && booking.measurements.contains(where: \.isMeasured)
    }

    /// The customer signs off only when the whole template got done: every surface measured, none
    /// skipped, not finished as partial (Matt, Oct 18). The server refuses otherwise.
    var signOffAllowed: Bool {
        booking.visitStatus == "completed" ? booking.visitOutcome == "accomplished" : isAllMeasured
    }

    /// Sign tab: once the customer has signed or the link is out, or when sign-off is due.
    var showsSignTab: Bool {
        signaturePending || booking.signatureCaptured || (requiresSignature && signOffAllowed)
    }

    var skippedCount: Int {
        booking.measurements.filter { $0.status == "skipped" }.count
    }

    var canComplete: Bool {
        let hasMeasurements = !booking.measurements.isEmpty
        let atLeastOneMeasured = booking.measurements.contains(where: \.isMeasured)
        // Not gated on completionBlockers: tapping Complete is what re-checks them, so gating here
        // left the button dead after the tech fixed what was missing. The sheets block instead.
        return hasMeasurements && atLeastOneMeasured && !isValidating
    }

    var allSkippedHaveReasons: Bool {
        booking.measurements
            .filter { !$0.isMeasured }
            .allSatisfy { $0.skipReason != nil && !$0.skipReason!.isEmpty }
    }

    func determineOutcome() -> String {
        if isAllMeasured {
            return "accomplished"
        } else {
            return "partial_surfaces"
        }
    }

    /// Called from bottom bar — validates server-side, then routes to full completion or partial sheet
    func initiateCompletion() {
        Task { @MainActor in
            await validateCompletion()
            if isAllMeasured {
                showCompletionSheet = true
            } else {
                showPartialSheet = true
            }
        }
    }

    @MainActor
    func validateCompletion() async {
        guard let appState, let visitId = booking.visitId else { return }

        isValidating = true
        error = nil

        do {
            let response: ValidateVisitCompletionResponse = try await appState.supabaseManager.client
                .rpc("validate_visit_completion", params: ["p_visit_id": visitId.uuidString])
                .execute()
                .value

            completionBlockers = response.blockers
            skippedSurfaceInfo = response.skippedSurfaces
            requiresSignature = response.requiresSignature
        } catch {
            // Don't pretend everything is fine: say the check failed. The server checks
            // again when the visit is completed, so nothing incomplete can slip through.
            completionBlockers = []
            requiresSignature = false
            self.error = "Couldn't check what's still needed to finish this visit: \(error.localizedDescription)"
        }

        isValidating = false
    }

    @MainActor
    func completeVisit(context: ModelContext) async {
        guard let appState, let visitId = booking.visitId, let staffId = appState.staffId else { return }

        isCompleting = true
        error = nil

        let outcome = determineOutcome()

        // Save skip reasons for skipped measurements before completing
        for measurement in booking.measurements where !measurement.isMeasured {
            if measurement.status != "skipped" {
                measurement.status = "skipped"
            }
            scheduleMeasurementSync(measurement: measurement, context: context)
        }

        do {
            var params = appState.locationManager.rpcCoordinateParams
            params["p_visit_id"] = visitId.uuidString
            params["p_worker_id"] = staffId.uuidString
            params["p_outcome"] = outcome
            params["p_notes"] = completionNotes
            let response: CompleteVisitResponse = try await appState.supabaseManager.client
                .rpc("complete_template_visit", params: params)
                .execute()
                .value

            if !response.success {
                // Server-side validation caught blockers
                self.error = response.blockers?.first?.message ?? "Cannot complete visit — requirements not met"
                self.completionBlockers = response.blockers ?? []
                isCompleting = false
                return
            }

            signaturePending = response.signaturePending ?? false
            signoffWithheld = response.signatureNotAllowed ?? false

            booking.visitStatus = "completed"
            booking.visitCompletedAt = Date()
            booking.visitOutcome = response.outcome ?? outcome
            // Mark surfaces as templated based on which measurements are done
            for measurement in booking.measurements where measurement.isMeasured {
                if let surface = booking.surfaces.first(where: { $0.surfaceId == measurement.surfaceId }) {
                    surface.actualLengthInches = measurement.actualLengthIn
                    surface.actualWidthInches = measurement.actualWidthIn
                    surface.actualSqft = measurement.actualSqft
                    surface.templateNotes = measurement.templateNotes
                    surface.isTemplated = true
                }
            }
            try? context.save()
        } catch {
            self.error = "Failed to complete visit: \(error.localizedDescription)"
        }

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
}

enum VisitTab: String, CaseIterable {
    case measurements = "Measure"
    case site = "Site"
    case photos = "Photos"
    case checklist = "Check"
    case signature = "Sign"
}

// MARK: - Completion Validation Models

struct CompletionBlocker: Codable, Identifiable {
    let ruleType: String
    let targetId: UUID?
    let targetLabel: String
    let message: String

    var id: String { "\(ruleType)-\(targetId?.uuidString ?? "nil")" }

    enum CodingKeys: String, CodingKey {
        case ruleType = "rule_type"
        case targetId = "target_id"
        case targetLabel = "target_label"
        case message
    }
}

struct SkippedSurfaceInfo: Codable, Identifiable {
    let surfaceId: UUID
    let name: String
    let skipReason: String

    var id: UUID { surfaceId }

    enum CodingKeys: String, CodingKey {
        case surfaceId = "surface_id"
        case name
        case skipReason = "skip_reason"
    }
}

struct ValidateVisitCompletionResponse: Codable {
    let canComplete: Bool
    let outcome: String
    let blockers: [CompletionBlocker]
    let skippedSurfaces: [SkippedSurfaceInfo]
    let requiresSignature: Bool

    enum CodingKeys: String, CodingKey {
        case canComplete = "can_complete"
        case outcome
        case blockers
        case skippedSurfaces = "skipped_surfaces"
        case requiresSignature = "requires_signature"
    }
}

struct CompleteVisitResponse: Codable {
    let success: Bool
    let outcome: String?
    let signaturePending: Bool?
    let signatureToken: String?
    let blockers: [CompletionBlocker]?
    /// Finished as partial, so the customer isn't asked to sign off yet.
    let signatureNotAllowed: Bool?

    enum CodingKeys: String, CodingKey {
        case success
        case outcome
        case signaturePending = "signature_pending"
        case signatureToken = "signature_token"
        case blockers
        case signatureNotAllowed = "signature_not_allowed"
    }
}
