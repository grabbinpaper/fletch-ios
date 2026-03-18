import Foundation
import SwiftData

/// Manages debounced auto-save of visit state to Supabase.
/// Aggregates changes across all tabs and saves as a single JSONB draft.
@Observable
final class DraftManager {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case error(String)
    }

    private(set) var state: SaveState = .idle
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: Duration = .seconds(2)

    /// Mark that something changed — resets the debounce timer
    func markDirty(
        visitId: UUID,
        booking: CachedBooking,
        checklistItems: [CachedChecklistItem],
        completionNotes: String,
        appState: AppState?,
        context: ModelContext
    ) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: self?.debounceInterval ?? .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.saveDraft(
                visitId: visitId,
                booking: booking,
                checklistItems: checklistItems,
                completionNotes: completionNotes,
                appState: appState,
                context: context
            )
        }
    }

    /// Force an immediate save (e.g. on app background)
    func saveNow(
        visitId: UUID,
        booking: CachedBooking,
        checklistItems: [CachedChecklistItem],
        completionNotes: String,
        appState: AppState?,
        context: ModelContext
    ) {
        debounceTask?.cancel()
        Task {
            await saveDraft(
                visitId: visitId,
                booking: booking,
                checklistItems: checklistItems,
                completionNotes: completionNotes,
                appState: appState,
                context: context
            )
        }
    }

    @MainActor
    private func saveDraft(
        visitId: UUID,
        booking: CachedBooking,
        checklistItems: [CachedChecklistItem],
        completionNotes: String,
        appState: AppState?,
        context: ModelContext
    ) async {
        guard let appState, appState.networkMonitor.isConnected else { return }

        state = .saving

        let draft = buildDraftPayload(
            booking: booking,
            checklistItems: checklistItems,
            completionNotes: completionNotes
        )

        guard let jsonData = try? JSONEncoder().encode(draft),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            state = .error("Failed to encode draft")
            return
        }

        do {
            try await appState.supabaseManager.client
                .rpc("save_visit_draft", params: [
                    "p_visit_id": visitId.uuidString,
                    "p_draft_json": jsonString
                ])
                .execute()

            state = .saved

            // Reset to idle after a delay so the indicator shows briefly
            try? await Task.sleep(for: .seconds(3))
            if state == .saved {
                state = .idle
            }
        } catch {
            state = .error("Draft save failed")
            // Reset after a delay
            try? await Task.sleep(for: .seconds(5))
            if case .error = state {
                state = .idle
            }
        }
    }

    private func buildDraftPayload(
        booking: CachedBooking,
        checklistItems: [CachedChecklistItem],
        completionNotes: String
    ) -> VisitDraftPayload {
        let measurements = booking.measurements.map { m in
            DraftMeasurement(
                measurementId: m.measurementId,
                surfaceId: m.surfaceId,
                actualLengthIn: m.actualLengthIn,
                actualWidthIn: m.actualWidthIn,
                actualSqft: m.actualSqft,
                edgeProfileId: m.edgeProfileId,
                edgeChanged: m.edgeChanged,
                overhangDepthIn: m.overhangDepthIn,
                backsplashIncluded: m.backsplashIncluded,
                backsplashHeightIn: m.backsplashHeightIn,
                seamLocationsJson: m.seamLocationsJson,
                finishedEnds: m.finishedEnds,
                finishedEdges: m.finishedEdges,
                templateNotes: m.templateNotes,
                status: m.status,
                skipReason: m.skipReason,
                backsplashMeasurements: m.backsplashMeasurements.map { bm in
                    DraftBacksplashMeasurement(
                        backsplashMeasurementId: bm.backsplashMeasurementId,
                        location: bm.location,
                        actualHeightIn: bm.actualHeightIn,
                        actualLengthIn: bm.actualLengthIn,
                        finishedEnds: bm.finishedEnds,
                        source: bm.source,
                        notes: bm.notes
                    )
                }
            )
        }

        let checklist = checklistItems.map { item in
            DraftChecklistItem(
                itemId: item.itemId,
                status: item.status,
                notes: item.notes,
                responseValue: item.responseValue
            )
        }

        return VisitDraftPayload(
            measurements: measurements,
            checklistItems: checklist,
            completionNotes: completionNotes.isEmpty ? nil : completionNotes,
            savedAt: Date().ISO8601Format()
        )
    }
}

// MARK: - Draft Payload Types

struct VisitDraftPayload: Codable {
    let measurements: [DraftMeasurement]
    let checklistItems: [DraftChecklistItem]
    let completionNotes: String?
    let savedAt: String
}

struct DraftMeasurement: Codable {
    let measurementId: UUID
    let surfaceId: UUID
    let actualLengthIn: Double?
    let actualWidthIn: Double?
    let actualSqft: Double?
    let edgeProfileId: UUID?
    let edgeChanged: Bool
    let overhangDepthIn: Double?
    let backsplashIncluded: Bool?
    let backsplashHeightIn: Double?
    let seamLocationsJson: String?
    let finishedEnds: String
    let finishedEdges: String
    let templateNotes: String?
    let status: String
    let skipReason: String?
    let backsplashMeasurements: [DraftBacksplashMeasurement]
}

struct DraftBacksplashMeasurement: Codable {
    let backsplashMeasurementId: UUID
    let location: String
    let actualHeightIn: Double?
    let actualLengthIn: Double?
    let finishedEnds: Int
    let source: String
    let notes: String?
}

struct DraftChecklistItem: Codable {
    let itemId: UUID
    let status: String
    let notes: String?
    let responseValue: String?
}
