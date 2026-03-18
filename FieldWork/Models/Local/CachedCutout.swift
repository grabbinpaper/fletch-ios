import Foundation
import SwiftData

@Model
final class CachedCutout {
    @Attribute(.unique) var cutoutId: UUID
    var visitId: UUID
    var measurementId: UUID
    var cutoutType: String
    var source: String
    var make: String?
    var modelName: String?
    var sinkInstallType: String?
    var faucetHoles: Int?
    var bringToShop: Bool
    var cooktopOnsite: Bool?
    var count: Int
    var locationNote: String?
    var changedFromQuote: Bool

    @Relationship var measurement: CachedMeasurement?

    init(
        cutoutId: UUID = UUID(),
        visitId: UUID,
        measurementId: UUID,
        cutoutType: String,
        source: String = "field",
        make: String? = nil,
        modelName: String? = nil,
        sinkInstallType: String? = nil,
        faucetHoles: Int? = nil,
        bringToShop: Bool = false,
        cooktopOnsite: Bool? = nil,
        count: Int = 1,
        locationNote: String? = nil,
        changedFromQuote: Bool = false
    ) {
        self.cutoutId = cutoutId
        self.visitId = visitId
        self.measurementId = measurementId
        self.cutoutType = cutoutType
        self.source = source
        self.make = make
        self.modelName = modelName
        self.sinkInstallType = sinkInstallType
        self.faucetHoles = faucetHoles
        self.bringToShop = bringToShop
        self.cooktopOnsite = cooktopOnsite
        self.count = count
        self.locationNote = locationNote
        self.changedFromQuote = changedFromQuote
    }

    var displayType: String {
        switch cutoutType {
        case "sink": return "Sink"
        case "cooktop": return "Cooktop"
        case "soap_dispenser": return "Soap Dispenser"
        case "air_gap": return "Air Gap"
        case "outlet_popup": return "Outlet/Popup"
        case "electrical_outlet": return "Electrical Outlet"
        case "other": return "Other"
        default: return cutoutType.capitalized
        }
    }

    var displayDetail: String {
        var parts: [String] = []
        if let make, !make.isEmpty { parts.append(make) }
        if let modelName, !modelName.isEmpty { parts.append(modelName) }
        if cutoutType == "sink", let installType = sinkInstallType {
            parts.append(installType.replacingOccurrences(of: "_", with: " ").capitalized)
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}
