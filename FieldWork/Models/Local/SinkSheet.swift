import Foundation

// The sink & faucet sheet (Fletch Plan 2c) as FieldWork sees it on a template visit: one per sink
// cutout, made in the office and signed by the customer. The tech confirms it against the real
// sink and faucet on site, or records what's different. Same rules as the database's
// visit_cutout_differences (the office's copy of "what changed" is worked out there).

/// A hole to drill: at one of the sink's positions (inches from the cutout's centre line,
/// minus = left), for the faucet or an extra ("extra:<id>").
struct SheetHole: Codable, Hashable {
    var x: Double
    var use: String
}

struct SheetExtra: Codable, Hashable {
    let id: String
    let type: String?
    let makeModel: String?
    let holeSize: Double?
    let suppliedBy: String?

    enum CodingKeys: String, CodingKey {
        case id, type
        case makeModel = "make_model"
        case holeSize = "hole_size"
        case suppliedBy = "supplied_by"
    }

    var label: String {
        switch type {
        case "soap_dispenser": return "Soap dispenser"
        case "reverse_osmosis": return "Reverse osmosis"
        case "air_gap": return "Air gap"
        default: return "Extra"
        }
    }
}

/// The sheet as it was when the visit started (visit_cutout.quoted).
struct QuotedSinkSheet: Codable {
    let version: Int?
    let sinkName: String?
    let sinkMake: String?
    let sinkModel: String?
    let sinkMount: String?
    let sinkShape: String?
    let sinkSuppliedBy: String?
    let sinkCutoutWidth: Double?
    let sinkCutoutDepth: Double?
    let sinkHolePositions: [Double]?
    let sinkMaxHoles: Int?
    let faucetName: String?
    let faucetMake: String?
    let faucetModel: String?
    let faucetSuppliedBy: String?
    let faucetHoleCount: Int?
    let faucetHoleSpacing: Double?
    let faucetHoleSize: Double?
    let extras: [SheetExtra]?
    let holes: [SheetHole]?
    let note: String?
    let cutoutTolerance: Double?

    enum CodingKeys: String, CodingKey {
        case version, extras, holes, note
        case sinkName = "sink_name"
        case sinkMake = "sink_make"
        case sinkModel = "sink_model"
        case sinkMount = "sink_mount"
        case sinkShape = "sink_shape"
        case sinkSuppliedBy = "sink_supplied_by"
        case sinkCutoutWidth = "sink_cutout_width"
        case sinkCutoutDepth = "sink_cutout_depth"
        case sinkHolePositions = "sink_hole_positions"
        case sinkMaxHoles = "sink_max_holes"
        case faucetName = "faucet_name"
        case faucetMake = "faucet_make"
        case faucetModel = "faucet_model"
        case faucetSuppliedBy = "faucet_supplied_by"
        case faucetHoleCount = "faucet_hole_count"
        case faucetHoleSpacing = "faucet_hole_spacing"
        case faucetHoleSize = "faucet_hole_size"
        case cutoutTolerance = "cutout_tolerance"
    }

    var sinkTitle: String { [sinkMake, sinkModel].compactMap { $0 }.joined(separator: " ").nonEmpty ?? sinkName ?? "Sink" }
    var faucetTitle: String? { [faucetMake, faucetModel].compactMap { $0 }.joined(separator: " ").nonEmpty ?? faucetName }
    var hasFaucet: Bool { faucetTitle != nil || (faucetHoleCount ?? 0) > 0 }
    var tolerance: Double { cutoutTolerance ?? 0.125 }
    var positions: [Double] { (sinkHolePositions ?? []).sorted() }

    /// What each hole can be for, in order: the faucet (up to `faucetHoles`), then extras with a hole.
    func holeUses(faucetHoles: Int?) -> [(use: String, label: String, max: Int)] {
        var uses: [(String, String, Int)] = []
        let n = faucetHoles ?? faucetHoleCount ?? 0
        if n > 0 { uses.append(("faucet", "Faucet", n)) }
        for e in extras ?? [] where (e.holeSize ?? 0) > 0 { uses.append(("extra:\(e.id)", e.label, 1)) }
        return uses
    }

    func label(forUse use: String) -> String {
        if use == "faucet" { return "Faucet" }
        return extras?.first { "extra:\($0.id)" == use }?.label ?? "Extra"
    }

    /// "Faucet: 4" left, centre, 4" right; Soap dispenser: 12" right" — like the office's sheet.
    func holesInWords(_ holes: [SheetHole]) -> String {
        let uses = Set(holes.map(\.use))
        let ordered = holeUses(faucetHoles: 6).map(\.use).filter { uses.contains($0) }
            + uses.filter { u in !holeUses(faucetHoles: 6).contains { $0.use == u } }.sorted()
        let words = ordered.map { use -> String in
            let xs = holes.filter { $0.use == use }.map(\.x).sorted()
            return "\(label(forUse: use)): " + xs.map(Inches.position).joined(separator: ", ")
        }
        return words.isEmpty ? "no holes" : words.joined(separator: "; ")
    }
}

/// What the tech found on site for one quoted sink.
struct SinkCheck: Equatable {
    var make: String?
    var model: String?
    var mount: String?
    var measuredWidth: Double?
    var measuredDepth: Double?
    var faucetMake: String?
    var faucetModel: String?
    var faucetHoles: Int?
    var holes: [SheetHole]
    var sinkOnSite: Bool?
    var faucetOnSite: Bool?

    private static func norm(_ parts: String?...) -> String {
        parts.compactMap { $0 }.joined().lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func sortedHoles(_ h: [SheetHole]) -> [SheetHole] {
        h.sorted { ($0.use, $0.x) < ($1.use, $1.x) }
    }

    /// What differs from the sheet — the same keys and rules as the database: sink, mount, cutout,
    /// faucet, faucet_holes, holes. Something the sheet didn't say isn't a difference.
    func differences(from q: QuotedSinkSheet) -> [String] {
        var out: [String] = []
        let qSink = Self.norm(q.sinkMake, q.sinkModel)
        if !qSink.isEmpty && qSink != Self.norm(make, model) { out.append("sink") }
        if let qm = q.sinkMount, mount != qm { out.append("mount") }
        if let w = measuredWidth, let d = measuredDepth, let qw = q.sinkCutoutWidth, let qd = q.sinkCutoutDepth,
           abs(w - qw) > q.tolerance || abs(d - qd) > q.tolerance { out.append("cutout") }
        let qFaucet = Self.norm(q.faucetMake, q.faucetModel)
        if !qFaucet.isEmpty && qFaucet != Self.norm(faucetMake, faucetModel) { out.append("faucet") }
        if let qn = q.faucetHoleCount, faucetHoles != qn { out.append("faucet_holes") }
        if Self.sortedHoles(holes) != Self.sortedHoles(q.holes ?? []) { out.append("holes") }
        return out
    }

    /// Old → new for each difference, in plain words for the tech.
    func changeLines(from q: QuotedSinkSheet) -> [String] {
        differences(from: q).map { key in
            switch key {
            case "sink": return "Sink: \(q.sinkTitle) → \([make, model].compactMap { $0 }.joined(separator: " ").nonEmpty ?? "none")"
            case "mount": return "Mount: \(SinkCheck.mountLabel(q.sinkMount)) → \(SinkCheck.mountLabel(mount))"
            case "cutout": return "Cutout: \(Inches.size(q.sinkCutoutWidth, q.sinkCutoutDepth)) → \(Inches.size(measuredWidth, measuredDepth))"
            case "faucet": return "Faucet: \(q.faucetTitle ?? "none") → \([faucetMake, faucetModel].compactMap { $0 }.joined(separator: " ").nonEmpty ?? "none")"
            case "faucet_holes": return "Faucet holes: \(q.faucetHoleCount.map(String.init) ?? "not set") → \(faucetHoles.map(String.init) ?? "not set")"
            case "holes": return "Holes: \(q.holesInWords(q.holes ?? [])) → \(q.holesInWords(holes))"
            default: return key
            }
        }
    }

    /// What's still needed before this sink counts as checked (same as the office's
    /// visit_cutout_missing_evidence). Photos are counted by the caller.
    /// `laser`: the laser captures the cutout, so it isn't measured by hand.
    func missingEvidence(quoted q: QuotedSinkSheet, hasSinkPhoto: Bool, hasFaucetPhoto: Bool, laser: Bool = false) -> [String] {
        var out: [String] = []
        if sinkOnSite == nil { out.append("Say whether the sink is on site") }
        if sinkOnSite == true {
            if !hasSinkPhoto { out.append("Photo of the sink's box label or model number") }
            if !laser && (measuredWidth == nil || measuredDepth == nil) { out.append("Measure the sink's cutout") }
        }
        if q.hasFaucet && !hasFaucetPhoto { out.append("Photo of the faucet or its spec sheet") }
        return out
    }

    static let mounts: [(String, String)] = [
        ("undermount", "Undermount"), ("drop_in", "Drop-in"), ("farmhouse", "Farmhouse"), ("vessel", "Vessel"),
    ]
    static func mountLabel(_ m: String?) -> String { mounts.first { $0.0 == m }?.1 ?? "not set" }
}

/// Inches as shops write them: 29 1/2", read from "29 1/2", "29-1/2", "29½" or "29.5".
enum Inches {
    static func format(_ v: Double) -> String {
        let sixteenths = Int((v * 16).rounded())
        let whole = sixteenths / 16
        var num = sixteenths % 16
        var den = 16
        while num > 0 && num % 2 == 0 { num /= 2; den /= 2 }
        if num == 0 { return "\(whole)\"" }
        return whole == 0 ? "\(num)/\(den)\"" : "\(whole) \(num)/\(den)\""
    }

    static func size(_ w: Double?, _ d: Double?) -> String {
        guard let w, let d else { return "not measured" }
        return "\(format(w)) × \(format(d))"
    }

    static func position(_ x: Double) -> String {
        x == 0 ? "centre" : "\(format(abs(x))) \(x < 0 ? "left" : "right")"
    }

    static func parse(_ text: String) -> Double? {
        let vulgar: [Character: String] = ["¼": " 1/4", "½": " 1/2", "¾": " 3/4", "⅛": " 1/8", "⅜": " 3/8", "⅝": " 5/8", "⅞": " 7/8"]
        var s = ""
        for c in text { s += vulgar[c] ?? String(c) }
        s = s.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "-", with: " ").trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return nil }
        if let d = Double(s) { return d > 0 ? d : nil }
        let parts = s.split(separator: " ").map(String.init)
        var total = 0.0
        for p in parts {
            if p.contains("/") {
                let nd = p.split(separator: "/").compactMap { Double($0) }
                guard nd.count == 2, nd[1] != 0 else { return nil }
                total += nd[0] / nd[1]
            } else if let d = Double(p) {
                total += d
            } else {
                return nil
            }
        }
        return total > 0 ? total : nil
    }
}

extension String {
    var nonEmpty: String? {
        let t = trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }
}
