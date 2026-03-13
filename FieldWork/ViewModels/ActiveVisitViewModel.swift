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
    var completionNotes = ""
    var error: String?

    private var appState: AppState?

    init(booking: CachedBooking) {
        self.booking = booking
    }

    func configure(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Measurements

    var measurementProgress: Double {
        let surfaces = booking.surfaces
        guard !surfaces.isEmpty else { return 0 }
        let measured = surfaces.filter { $0.actualLengthInches != nil && $0.actualWidthInches != nil }.count
        return Double(measured) / Double(surfaces.count)
    }

    func updateMeasurement(
        surface: CachedSurface,
        length: Double?,
        width: Double?,
        notes: String?,
        context: ModelContext
    ) {
        surface.actualLengthInches = length
        surface.actualWidthInches = width
        surface.templateNotes = notes

        if let l = length, let w = width {
            surface.actualSqft = (l * w) / 144.0  // Convert sq inches to sq ft
        } else {
            surface.actualSqft = nil
        }

        try? context.save()

        // Queue sync
        guard let appState else { return }
        let payload = SurfaceMeasurementPayload(
            surfaceId: surface.surfaceId,
            actualLengthInches: length,
            actualWidthInches: width,
            actualSqft: surface.actualSqft,
            templateNotes: notes
        )
        if let data = try? JSONEncoder().encode(payload) {
            Task {
                await appState.syncEngine.queueOperation(
                    type: "update_surface_measurements",
                    entityType: "surface",
                    entityId: surface.surfaceId.uuidString,
                    payload: data,
                    in: context
                )
            }
        }
    }

    // MARK: - Photos

    func capturePhoto(
        image: UIImage,
        surfaceId: UUID? = nil,
        caption: String? = nil,
        context: ModelContext
    ) {
        guard let appState, let jobId = booking.jobId else { return }

        // Save to documents directory
        let fileName = "\(UUID().uuidString).jpg"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)

        guard let jpegData = image.jpegData(compressionQuality: 0.8) else { return }
        try? jpegData.write(to: fileURL)

        let photo = CachedPhoto(
            localFilePath: fileURL.path,
            jobId: jobId,
            visitId: booking.visitId,
            surfaceId: surfaceId,
            caption: caption,
            latitude: appState.locationManager.latitude,
            longitude: appState.locationManager.longitude
        )
        context.insert(photo)
        photos.append(photo)
        try? context.save()

        // Queue upload
        let storagePath = "\(appState.organizationId?.uuidString ?? "unknown")/\(jobId.uuidString)/\(fileName)"
        let payload = PhotoUploadPayload(
            localFilePath: fileURL.path,
            storagePath: storagePath,
            fileName: fileName,
            mimeType: "image/jpeg",
            fileSizeBytes: jpegData.count,
            organizationId: appState.organizationId ?? UUID(),
            jobId: jobId,
            visitId: booking.visitId,
            surfaceId: surfaceId,
            uploadedBy: appState.staffId ?? UUID(),
            caption: caption,
            latitude: appState.locationManager.latitude,
            longitude: appState.locationManager.longitude
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

    // MARK: - Checklist

    func loadChecklist(context: ModelContext) {
        guard let visitId = booking.visitId else { return }

        // Try to load from remote
        Task {
            guard let appState, appState.networkMonitor.isConnected else {
                loadChecklistFromCache(visitId: visitId, context: context)
                return
            }

            do {
                // Get the visit_checklist for this visit
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
                    return
                }

                let items: [ChecklistItemResponse] = try await appState.supabaseManager.client
                    .from("visit_checklist_item")
                    .select()
                    .eq("visit_checklist_id", value: checklistId.uuidString)
                    .order("display_order")
                    .execute()
                    .value

                // Cache locally
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

    func updateChecklistItem(
        _ item: CachedChecklistItem,
        status: String,
        notes: String? = nil,
        context: ModelContext
    ) {
        item.status = status
        item.notes = notes
        try? context.save()

        guard let appState else { return }
        let payload = ChecklistItemPayload(
            itemId: item.itemId,
            status: status,
            notes: notes,
            checkedAt: Date(),
            checkedBy: appState.staffId
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

    // MARK: - Signature

    func saveSignature(image: UIImage, signerName: String, context: ModelContext) {
        guard let appState, let visitId = booking.visitId else { return }

        let fileName = "signature_\(visitId.uuidString).png"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)

        guard let pngData = image.pngData() else { return }
        try? pngData.write(to: fileURL)

        booking.signatureCaptured = true
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

    var canComplete: Bool {
        let allMeasured = booking.surfaces.allSatisfy {
            $0.actualLengthInches != nil && $0.actualWidthInches != nil
        }
        let requiredChecklistDone = checklistItems
            .filter { $0.status == "pending" }
            .isEmpty || checklistItems.isEmpty
        let signatureOk = !booking.signatureRequired || booking.signatureCaptured

        return allMeasured && requiredChecklistDone && signatureOk
    }

    @MainActor
    func completeVisit(context: ModelContext) async {
        guard let appState, let visitId = booking.visitId, let staffId = appState.staffId else { return }

        isCompleting = true
        error = nil

        do {
            let lat = appState.locationManager.latitude
            let lng = appState.locationManager.longitude

            let params: [String: String] = [
                "p_visit_id": visitId.uuidString,
                "p_worker_id": staffId.uuidString,
                "p_lat": lat.map { "\($0)" } ?? "",
                "p_lng": lng.map { "\($0)" } ?? "",
                "p_outcome": "accomplished",
                "p_notes": completionNotes
            ]
            try await appState.supabaseManager.client
                .rpc("complete_template_visit", params: params)
                .execute()

            booking.visitStatus = "completed"
            booking.visitCompletedAt = Date()
            booking.visitOutcome = "accomplished"
            for surface in booking.surfaces {
                surface.isTemplated = true
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
    case measurements = "Measurements"
    case photos = "Photos"
    case checklist = "Checklist"
    case signature = "Signature"
}
