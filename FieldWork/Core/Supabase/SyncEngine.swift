import Foundation
import SwiftData

actor SyncEngine {
    private let supabase: SupabaseManager
    private let modelContainer: ModelContainer
    private let networkMonitor: NetworkMonitor

    private var isProcessing = false
    private var retryCount = 0
    private let maxRetries = 5

    enum SyncStatus: Sendable {
        case idle
        case syncing
        case error(String)
    }

    private(set) var status: SyncStatus = .idle

    init(supabase: SupabaseManager, modelContainer: ModelContainer, networkMonitor: NetworkMonitor) {
        self.supabase = supabase
        self.modelContainer = modelContainer
        self.networkMonitor = networkMonitor
    }

    func processPendingOperations() async {
        guard !isProcessing else { return }
        guard networkMonitor.isConnected else {
            status = .error("Offline")
            return
        }

        isProcessing = true
        status = .syncing

        let context = ModelContext(modelContainer)

        do {
            let descriptor = FetchDescriptor<SyncOperation>(
                predicate: #Predicate { $0.status == "pending" },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            let operations = try context.fetch(descriptor)

            for operation in operations {
                do {
                    try await executeOperation(operation)
                    operation.status = "completed"
                    operation.completedAt = Date()
                    retryCount = 0
                } catch {
                    operation.retryCount += 1
                    operation.lastError = error.localizedDescription

                    if operation.retryCount >= maxRetries {
                        operation.status = "failed"
                    }
                    print("Sync operation failed: \(error)")
                }
            }

            try context.save()
            status = .idle
        } catch {
            status = .error(error.localizedDescription)
        }

        isProcessing = false
    }

    func queueOperation(
        type: String,
        entityType: String,
        entityId: String,
        payload: Data,
        in context: ModelContext
    ) {
        let op = SyncOperation(
            operationType: type,
            entityType: entityType,
            entityId: entityId,
            payload: payload
        )
        context.insert(op)
        try? context.save()

        Task {
            await processPendingOperations()
        }
    }

    var pendingCount: Int {
        get async {
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<SyncOperation>(
                predicate: #Predicate { $0.status == "pending" }
            )
            return (try? context.fetchCount(descriptor)) ?? 0
        }
    }

    var failedCount: Int {
        get async {
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<SyncOperation>(
                predicate: #Predicate { $0.status == "failed" }
            )
            return (try? context.fetchCount(descriptor)) ?? 0
        }
    }

    private func executeOperation(_ operation: SyncOperation) async throws {
        switch operation.operationType {
        case "update_surface_measurements":
            try await syncSurfaceMeasurements(operation)
        case "upload_photo":
            try await syncPhotoUpload(operation)
        case "update_checklist_item":
            try await syncChecklistItem(operation)
        case "upload_signature":
            try await syncSignatureUpload(operation)
        case "rpc":
            try await syncRPCCall(operation)
        default:
            print("Unknown operation type: \(operation.operationType)")
        }
    }

    private func syncSurfaceMeasurements(_ operation: SyncOperation) async throws {
        let payload = try JSONDecoder().decode(SurfaceMeasurementPayload.self, from: operation.payload)

        struct SurfaceUpdate: Encodable {
            let actual_length_inches: Double?
            let actual_width_inches: Double?
            let actual_sqft: Double?
            let template_notes: String?
        }

        try await supabase.client
            .from("surface")
            .update(SurfaceUpdate(
                actual_length_inches: payload.actualLengthInches,
                actual_width_inches: payload.actualWidthInches,
                actual_sqft: payload.actualSqft,
                template_notes: payload.templateNotes
            ))
            .eq("surface_id", value: payload.surfaceId.uuidString)
            .execute()
    }

    private func syncPhotoUpload(_ operation: SyncOperation) async throws {
        let payload = try JSONDecoder().decode(PhotoUploadPayload.self, from: operation.payload)
        let fileURL = URL(fileURLWithPath: payload.localFilePath)

        guard FileManager.default.fileExists(atPath: payload.localFilePath) else {
            throw SyncError.fileNotFound(payload.localFilePath)
        }

        let fileData = try Data(contentsOf: fileURL)

        // Upload compressed photo to storage
        try await supabase.client.storage
            .from("job-attachments")
            .upload(
                path: payload.storagePath,
                file: fileData,
                options: .init(contentType: payload.mimeType)
            )

        // Upload thumbnail if available
        var uploadedThumbPath: String?
        if let thumbLocal = payload.thumbnailLocalPath,
           let thumbStorage = payload.thumbnailStoragePath,
           FileManager.default.fileExists(atPath: thumbLocal) {
            let thumbData = try Data(contentsOf: URL(fileURLWithPath: thumbLocal))
            try await supabase.client.storage
                .from("job-attachments")
                .upload(
                    path: thumbStorage,
                    file: thumbData,
                    options: .init(contentType: "image/jpeg")
                )
            uploadedThumbPath = thumbStorage
        }

        // Create job_attachment record
        struct AttachmentInsert: Encodable {
            let organization_id: String
            let job_id: String
            let category: String
            let file_name: String
            let file_path: String
            let file_size_bytes: Int
            let mime_type: String
            let uploaded_by: String
            let notes: String
        }

        try await supabase.client
            .from("job_attachment")
            .insert(AttachmentInsert(
                organization_id: payload.organizationId.uuidString,
                job_id: payload.jobId.uuidString,
                category: "template_photo",
                file_name: payload.fileName,
                file_path: payload.storagePath,
                file_size_bytes: payload.fileSizeBytes,
                mime_type: payload.mimeType,
                uploaded_by: payload.uploadedBy.uuidString,
                notes: payload.caption ?? ""
            ))
            .execute()

        // If associated with a visit, also create visit_media
        if let visitId = payload.visitId {
            struct VisitMediaInsert: Encodable {
                let visit_id: String
                let media_type: String
                let file_path: String
                let file_name: String
                let file_size_bytes: Int
                let mime_type: String
                let captured_lat: Double?
                let captured_lng: Double?
                let caption: String?
                let uploaded_by: String
                let surface_id: String?
                let thumbnail_path: String?
                let has_annotations: Bool
            }

            try await supabase.client
                .from("visit_media")
                .insert(VisitMediaInsert(
                    visit_id: visitId.uuidString,
                    media_type: "photo",
                    file_path: payload.storagePath,
                    file_name: payload.fileName,
                    file_size_bytes: payload.fileSizeBytes,
                    mime_type: payload.mimeType,
                    captured_lat: payload.latitude,
                    captured_lng: payload.longitude,
                    caption: payload.caption,
                    uploaded_by: payload.uploadedBy.uuidString,
                    surface_id: payload.surfaceId?.uuidString,
                    thumbnail_path: uploadedThumbPath,
                    has_annotations: payload.hasAnnotations
                ))
                .execute()
        }

        // Mark photo as synced in SwiftData
        let photoEntityId = operation.entityId
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedPhoto>(
            predicate: #Predicate { $0.localId.uuidString == photoEntityId }
        )
        if let photo = try? context.fetch(descriptor).first {
            photo.isSynced = true
            try? context.save()
        }
    }

    private func syncChecklistItem(_ operation: SyncOperation) async throws {
        let payload = try JSONDecoder().decode(ChecklistItemPayload.self, from: operation.payload)

        struct ChecklistItemUpdate: Encodable {
            let status: String
            let notes: String?
            let checked_at: String?
            let checked_by: String?
        }

        try await supabase.client
            .from("visit_checklist_item")
            .update(ChecklistItemUpdate(
                status: payload.status,
                notes: payload.notes,
                checked_at: payload.checkedAt?.ISO8601Format(),
                checked_by: payload.checkedBy?.uuidString
            ))
            .eq("visit_checklist_item_id", value: payload.itemId.uuidString)
            .execute()
    }

    private func syncSignatureUpload(_ operation: SyncOperation) async throws {
        let payload = try JSONDecoder().decode(SignatureUploadPayload.self, from: operation.payload)
        let fileURL = URL(fileURLWithPath: payload.localFilePath)

        guard FileManager.default.fileExists(atPath: payload.localFilePath) else {
            throw SyncError.fileNotFound(payload.localFilePath)
        }

        let fileData = try Data(contentsOf: fileURL)

        // Upload to visit-media bucket
        try await supabase.client.storage
            .from("visit-media")
            .upload(
                path: payload.storagePath,
                file: fileData,
                options: .init(contentType: "image/png")
            )

        // Create visit_media record
        struct SignatureMediaInsert: Encodable {
            let visit_id: String
            let media_type: String
            let file_path: String
            let file_name: String
            let signed_by_name: String
            let uploaded_by: String
        }

        try await supabase.client
            .from("visit_media")
            .insert(SignatureMediaInsert(
                visit_id: payload.visitId.uuidString,
                media_type: "signature",
                file_path: payload.storagePath,
                file_name: payload.fileName,
                signed_by_name: payload.signerName,
                uploaded_by: payload.uploadedBy.uuidString
            ))
            .execute()

        // Update visit signature fields
        struct SignatureVisitUpdate: Encodable {
            let signature_captured: Bool
            let signed_by_name: String
            let signed_at: String
        }

        try await supabase.client
            .from("field_service_visit")
            .update(SignatureVisitUpdate(
                signature_captured: true,
                signed_by_name: payload.signerName,
                signed_at: Date().ISO8601Format()
            ))
            .eq("visit_id", value: payload.visitId.uuidString)
            .execute()
    }

    private func syncRPCCall(_ operation: SyncOperation) async throws {
        let payload = try JSONDecoder().decode(RPCPayload.self, from: operation.payload)

        try await supabase.client
            .rpc(payload.functionName, params: payload.params)
            .execute()
    }
}

enum SyncError: LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}

// MARK: - Sync Payloads

struct SurfaceMeasurementPayload: Codable {
    let surfaceId: UUID
    let actualLengthInches: Double?
    let actualWidthInches: Double?
    let actualSqft: Double?
    let templateNotes: String?
}

struct PhotoUploadPayload: Codable {
    let localFilePath: String
    let storagePath: String
    let fileName: String
    let mimeType: String
    let fileSizeBytes: Int
    let organizationId: UUID
    let jobId: UUID
    let visitId: UUID?
    let surfaceId: UUID?
    let uploadedBy: UUID
    let caption: String?
    let latitude: Double?
    let longitude: Double?
    let thumbnailLocalPath: String?
    let thumbnailStoragePath: String?
    let hasAnnotations: Bool
}

struct ChecklistItemPayload: Codable {
    let itemId: UUID
    let status: String
    let notes: String?
    let checkedAt: Date?
    let checkedBy: UUID?
}

struct SignatureUploadPayload: Codable {
    let visitId: UUID
    let localFilePath: String
    let storagePath: String
    let fileName: String
    let signerName: String
    let uploadedBy: UUID
}

struct RPCPayload: Codable {
    let functionName: String
    let params: [String: String]
}
