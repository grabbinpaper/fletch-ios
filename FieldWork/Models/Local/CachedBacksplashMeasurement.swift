import Foundation
import SwiftData

@Model
final class CachedBacksplashMeasurement {
    @Attribute(.unique) var backsplashMeasurementId: UUID
    var visitId: UUID
    var measurementId: UUID
    var surfaceBacksplashId: UUID?
    var location: String
    var quotedHeightIn: Double?
    var quotedLengthIn: Double?
    var actualHeightIn: Double?
    var actualLengthIn: Double?
    var finishedEnds: Int
    var source: String
    var notes: String?

    @Relationship var measurement: CachedMeasurement?

    init(
        backsplashMeasurementId: UUID = UUID(),
        visitId: UUID,
        measurementId: UUID,
        surfaceBacksplashId: UUID? = nil,
        location: String,
        quotedHeightIn: Double? = nil,
        quotedLengthIn: Double? = nil,
        actualHeightIn: Double? = nil,
        actualLengthIn: Double? = nil,
        finishedEnds: Int = 0,
        source: String = "field",
        notes: String? = nil
    ) {
        self.backsplashMeasurementId = backsplashMeasurementId
        self.visitId = visitId
        self.measurementId = measurementId
        self.surfaceBacksplashId = surfaceBacksplashId
        self.location = location
        self.quotedHeightIn = quotedHeightIn
        self.quotedLengthIn = quotedLengthIn
        self.actualHeightIn = actualHeightIn
        self.actualLengthIn = actualLengthIn
        self.finishedEnds = finishedEnds
        self.source = source
        self.notes = notes
    }

    var displayLocation: String {
        switch location {
        case "left": return "Left Wall"
        case "back": return "Back Wall"
        case "right": return "Right Wall"
        default: return location.capitalized
        }
    }
}
