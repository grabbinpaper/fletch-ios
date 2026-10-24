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

    // A sink from the job's sink & faucet sheet (source "quoted"): the sheet as it was when the
    // visit started, and what the tech found on site. The office decides "changed" from these
    // (`differences`); `SinkCheck` works out the same on the phone so the tech sees it straight away.
    var sinkSheetId: UUID?
    var sinkSheetVersion: Int?
    var quotedJson: String?
    var faucetMake: String?
    var faucetModel: String?
    var holesJson: String?
    var measuredCutoutWidth: Double?
    var measuredCutoutDepth: Double?
    var sinkOnSite: Bool?
    var faucetOnSite: Bool?
    var checkedAt: Date?
    var differences: [String] = []
    /// Evidence photo categories the office already has ("sink_label", "faucet").
    var serverPhotoCategories: [String] = []

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

    var isQuotedSink: Bool { source == "quoted" && sinkSheetId != nil }

    /// The sink & faucet sheet as quoted (nil for cutouts the tech added).
    var quoted: QuotedSinkSheet? {
        guard let data = quotedJson?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(QuotedSinkSheet.self, from: data)
    }

    var holes: [SheetHole] {
        get {
            guard let data = holesJson?.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([SheetHole].self, from: data)) ?? []
        }
        set {
            holesJson = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    /// The tech's answers so far, for comparing with the sheet.
    var sinkCheck: SinkCheck {
        SinkCheck(make: make, model: modelName, mount: sinkInstallType, measuredWidth: measuredCutoutWidth,
                  measuredDepth: measuredCutoutDepth, faucetMake: faucetMake, faucetModel: faucetModel,
                  faucetHoles: faucetHoles, holes: holes, sinkOnSite: sinkOnSite, faucetOnSite: faucetOnSite)
    }

    /// Fills in a quoted sink from the schedule (the server's copy).
    func applyRemote(_ remote: ScheduleCutout) {
        make = remote.make
        modelName = remote.model
        sinkInstallType = remote.sinkInstallType
        faucetHoles = remote.faucetHoles
        bringToShop = remote.bringToShop ?? false
        count = remote.count ?? 1
        locationNote = remote.locationNote
        changedFromQuote = remote.changedFromQuote ?? false
        sinkSheetId = remote.sinkSheetId
        sinkSheetVersion = remote.sinkSheetVersion
        quotedJson = remote.quotedJson
        faucetMake = remote.faucetMake
        faucetModel = remote.faucetModel
        holesJson = remote.holesJson
        measuredCutoutWidth = remote.measuredCutoutWidth
        measuredCutoutDepth = remote.measuredCutoutDepth
        sinkOnSite = remote.sinkOnSite
        faucetOnSite = remote.faucetOnSite
        // Only "has it been checked" matters on the phone, so an odd date format still counts.
        checkedAt = remote.checkedAt.map { parseDatetime($0) ?? .distantPast }
        differences = remote.differences ?? []
        serverPhotoCategories = remote.photoCategories ?? []
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
