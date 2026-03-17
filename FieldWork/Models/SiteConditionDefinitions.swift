import Foundation

// MARK: - Detail Field Types

enum DetailFieldType {
    case picker([String])
    case intStepper(label: String, range: ClosedRange<Int>)
    case boolToggle
}

// MARK: - Condition Definition

struct SiteConditionDefinition: Identifiable {
    let id: String          // condition_key stored in DB
    let label: String
    let section: String
    let displayOrder: Int
    let detailLabel: String
    let detailFieldType: DetailFieldType
}

// MARK: - Predefined Conditions

enum SiteConditions {
    static let all: [SiteConditionDefinition] = [
        // Access & Delivery
        .init(id: "stairs", label: "Stairs", section: "Access & Delivery", displayOrder: 0,
              detailLabel: "Flights", detailFieldType: .intStepper(label: "Flights", range: 0...10)),
        .init(id: "narrow_hallway", label: "Narrow hallway", section: "Access & Delivery", displayOrder: 1,
              detailLabel: "Width", detailFieldType: .picker(["< 30in", "30–36in", "36+in"])),
        .init(id: "tight_corners", label: "Tight corners/turns", section: "Access & Delivery", displayOrder: 2,
              detailLabel: "Turns", detailFieldType: .intStepper(label: "Turns", range: 0...10)),
        .init(id: "elevator_required", label: "Elevator required", section: "Access & Delivery", displayOrder: 3,
              detailLabel: "Type", detailFieldType: .picker(["Standard", "Freight", "None"])),
        .init(id: "long_carry", label: "Long carry distance", section: "Access & Delivery", displayOrder: 4,
              detailLabel: "Distance", detailFieldType: .picker(["< 50ft", "50–100ft", "100–200ft", "200+ft"])),
        .init(id: "parking", label: "Truck parking", section: "Access & Delivery", displayOrder: 5,
              detailLabel: "Parking", detailFieldType: .picker(["Driveway", "Street", "Lot", "Loading dock", "Restricted"])),
        .init(id: "door_clearance", label: "Door clearance", section: "Access & Delivery", displayOrder: 6,
              detailLabel: "Clearance", detailFieldType: .picker(["Standard (32+in)", "Narrow (< 32in)", "Double door", "Sliding glass"])),

        // Site Status
        .init(id: "site_type", label: "Site type", section: "Site Status", displayOrder: 7,
              detailLabel: "Type", detailFieldType: .picker(["Occupied home", "Vacant home", "Active construction", "Commercial"])),
        .init(id: "other_trades", label: "Other trades on site", section: "Site Status", displayOrder: 8,
              detailLabel: "Present", detailFieldType: .boolToggle),
        .init(id: "pets_present", label: "Pets present", section: "Site Status", displayOrder: 9,
              detailLabel: "Present", detailFieldType: .boolToggle),

        // Existing Conditions
        .init(id: "existing_countertop", label: "Existing countertop", section: "Existing Conditions", displayOrder: 10,
              detailLabel: "Material", detailFieldType: .picker(["Laminate", "Tile", "Granite", "Quartz", "Marble", "Butcher block", "Concrete", "None"])),
        .init(id: "plumbing_state", label: "Plumbing condition", section: "Existing Conditions", displayOrder: 11,
              detailLabel: "Condition", detailFieldType: .picker(["Standard", "Corroded", "Non-standard", "Not yet roughed in"])),
        .init(id: "appliances_in_place", label: "Appliances in place", section: "Existing Conditions", displayOrder: 12,
              detailLabel: "In place", detailFieldType: .boolToggle),
        .init(id: "cabinets_level", label: "Cabinets level & secure", section: "Existing Conditions", displayOrder: 13,
              detailLabel: "Condition", detailFieldType: .picker(["Level & secure", "Minor shimming needed", "Significant issues"])),
        .init(id: "backsplash_existing", label: "Existing backsplash", section: "Existing Conditions", displayOrder: 14,
              detailLabel: "Type", detailFieldType: .picker(["None", "Tile", "Stone", "Other – needs removal"])),

        // Floor & Wall Protection
        .init(id: "floor_material", label: "Floor material", section: "Floor & Wall Protection", displayOrder: 15,
              detailLabel: "Material", detailFieldType: .picker(["Hardwood", "Tile", "LVP/Vinyl", "Carpet", "Concrete", "Unfinished"])),
        .init(id: "floor_protection", label: "Floor protection needed", section: "Floor & Wall Protection", displayOrder: 16,
              detailLabel: "Needed", detailFieldType: .boolToggle),
        .init(id: "wall_condition", label: "Wall condition near counters", section: "Floor & Wall Protection", displayOrder: 17,
              detailLabel: "Condition", detailFieldType: .picker(["Finished & painted", "Drywall – unfinished", "Tile", "Open framing"])),

        // Utilities
        .init(id: "water_shutoff", label: "Water shut-off accessible", section: "Utilities", displayOrder: 18,
              detailLabel: "Accessible", detailFieldType: .boolToggle),
        .init(id: "electrical_near_sink", label: "Electrical near sink", section: "Utilities", displayOrder: 19,
              detailLabel: "Status", detailFieldType: .picker(["None", "GFCI present", "Needs relocation"])),
        .init(id: "gas_line", label: "Gas line near work area", section: "Utilities", displayOrder: 20,
              detailLabel: "Present", detailFieldType: .boolToggle),
    ]

    /// Conditions grouped by section in display order
    static var sections: [(String, [SiteConditionDefinition])] {
        let grouped = Dictionary(grouping: all) { $0.section }
        let sectionOrder = ["Access & Delivery", "Site Status", "Existing Conditions", "Floor & Wall Protection", "Utilities"]
        return sectionOrder.compactMap { section in
            guard let items = grouped[section] else { return nil }
            return (section, items.sorted { $0.displayOrder < $1.displayOrder })
        }
    }

    /// Look up a definition by its key
    static func definition(for key: String) -> SiteConditionDefinition? {
        all.first { $0.id == key }
    }
}
