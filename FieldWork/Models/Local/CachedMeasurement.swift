import Foundation
import SwiftData

@Model
final class CachedMeasurement {
    @Attribute(.unique) var measurementId: UUID
    var visitId: UUID
    var surfaceId: UUID

    // Quoted values (snapshot from surface at visit start)
    var quotedLengthIn: Double?
    var quotedWidthIn: Double?
    var quotedSqft: Double?
    var quotedEdgeProfileId: UUID?

    // Actuals (field-measured)
    var actualLengthIn: Double?
    var actualWidthIn: Double?
    var actualSqft: Double?

    // Edge
    var edgeProfileId: UUID?
    var edgeChanged: Bool

    // Overhang & backsplash
    var overhangDepthIn: Double?
    var backsplashIncluded: Bool?
    var backsplashHeightIn: Double?

    // Seams & finished ends
    var seamLocationsJson: String?
    var finishedEnds: String

    // Notes & status
    var templateNotes: String?
    var status: String
    var skipReason: String?
    var isFieldAdded: Bool

    @Relationship var booking: CachedBooking?
    @Relationship(deleteRule: .cascade) var cutouts: [CachedCutout]

    init(from remote: ScheduleVisitMeasurement, visitId: UUID) {
        self.measurementId = remote.measurementId
        self.visitId = visitId
        self.surfaceId = remote.surfaceId
        self.quotedLengthIn = remote.quotedLengthIn
        self.quotedWidthIn = remote.quotedWidthIn
        self.quotedSqft = remote.quotedSqft
        self.quotedEdgeProfileId = remote.quotedEdgeProfileId
        self.actualLengthIn = remote.actualLengthIn
        self.actualWidthIn = remote.actualWidthIn
        self.actualSqft = remote.actualSqft
        self.edgeProfileId = remote.edgeProfileId
        self.edgeChanged = remote.edgeChanged ?? false
        self.overhangDepthIn = remote.overhangDepthIn
        self.backsplashIncluded = remote.backsplashIncluded
        self.backsplashHeightIn = remote.backsplashHeightIn
        self.seamLocationsJson = remote.seamLocationsJson
        self.finishedEnds = remote.finishedEnds ?? "none"
        self.templateNotes = remote.templateNotes
        self.status = remote.status
        self.skipReason = remote.skipReason
        self.isFieldAdded = remote.isFieldAdded ?? false
        self.cutouts = []
    }

    /// Creates a measurement for a field-added surface
    init(fieldAdded measurementId: UUID, visitId: UUID, surfaceId: UUID) {
        self.measurementId = measurementId
        self.visitId = visitId
        self.surfaceId = surfaceId
        self.quotedLengthIn = nil
        self.quotedWidthIn = nil
        self.quotedSqft = nil
        self.quotedEdgeProfileId = nil
        self.actualLengthIn = nil
        self.actualWidthIn = nil
        self.actualSqft = nil
        self.edgeProfileId = nil
        self.edgeChanged = false
        self.overhangDepthIn = nil
        self.backsplashIncluded = nil
        self.backsplashHeightIn = nil
        self.seamLocationsJson = nil
        self.finishedEnds = "none"
        self.templateNotes = nil
        self.status = "pending"
        self.skipReason = nil
        self.isFieldAdded = true
        self.cutouts = []
    }

    func update(from remote: ScheduleVisitMeasurement) {
        self.quotedLengthIn = remote.quotedLengthIn
        self.quotedWidthIn = remote.quotedWidthIn
        self.quotedSqft = remote.quotedSqft
        self.quotedEdgeProfileId = remote.quotedEdgeProfileId
        self.actualLengthIn = remote.actualLengthIn
        self.actualWidthIn = remote.actualWidthIn
        self.actualSqft = remote.actualSqft
        self.edgeProfileId = remote.edgeProfileId
        self.edgeChanged = remote.edgeChanged ?? false
        self.overhangDepthIn = remote.overhangDepthIn
        self.backsplashIncluded = remote.backsplashIncluded
        self.backsplashHeightIn = remote.backsplashHeightIn
        self.seamLocationsJson = remote.seamLocationsJson
        self.finishedEnds = remote.finishedEnds ?? "none"
        self.templateNotes = remote.templateNotes
        self.status = remote.status
        self.skipReason = remote.skipReason
        self.isFieldAdded = remote.isFieldAdded ?? false
    }

    /// Whether actual dimensions differ from quoted
    var hasDimensionChange: Bool {
        guard let qL = quotedLengthIn, let qW = quotedWidthIn,
              let aL = actualLengthIn, let aW = actualWidthIn else { return false }
        return abs(qL - aL) > 0.01 || abs(qW - aW) > 0.01
    }

    var isMeasured: Bool {
        actualLengthIn != nil && actualWidthIn != nil
    }
}
