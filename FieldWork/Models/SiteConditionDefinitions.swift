import Foundation

struct SiteTag: Identifiable {
    let id: String
    let label: String
    let section: String
}

enum SiteTags {
    static let all: [SiteTag] = [
        // Access & Delivery
        .init(id: "stairs", label: "Stairs", section: "Access & Delivery"),
        .init(id: "narrow_hallway", label: "Narrow hallway", section: "Access & Delivery"),
        .init(id: "tight_corners", label: "Tight corners", section: "Access & Delivery"),
        .init(id: "elevator_required", label: "Elevator required", section: "Access & Delivery"),
        .init(id: "long_carry", label: "Long carry", section: "Access & Delivery"),
        .init(id: "parking", label: "Parking", section: "Access & Delivery"),
        .init(id: "door_clearance", label: "Door clearance", section: "Access & Delivery"),
        .init(id: "hill_elevation", label: "Hill/Elevation", section: "Access & Delivery"),
        .init(id: "rugged_terrain", label: "Rugged terrain", section: "Access & Delivery"),
        .init(id: "fence_gate", label: "Fence/Gate", section: "Access & Delivery"),

        // Site Status
        .init(id: "site_type", label: "Site type", section: "Site Status"),
        .init(id: "other_trades", label: "Other trades", section: "Site Status"),
        .init(id: "pets_present", label: "Pets", section: "Site Status"),

        // Existing Conditions
        .init(id: "existing_countertop", label: "Existing countertop", section: "Existing Conditions"),
        .init(id: "plumbing_state", label: "Plumbing", section: "Existing Conditions"),
        .init(id: "appliances_in_place", label: "Appliances", section: "Existing Conditions"),
        .init(id: "cabinets_level", label: "Cabinets", section: "Existing Conditions"),
        .init(id: "backsplash_existing", label: "Backsplash", section: "Existing Conditions"),

        // Floor & Wall
        .init(id: "floor_material", label: "Floor material", section: "Floor & Wall"),
        .init(id: "floor_protection", label: "Floor protection", section: "Floor & Wall"),
        .init(id: "wall_condition", label: "Wall condition", section: "Floor & Wall"),

        // Utilities
        .init(id: "water_shutoff", label: "Water shut-off", section: "Utilities"),
        .init(id: "electrical_near_sink", label: "Electrical", section: "Utilities"),
        .init(id: "gas_line", label: "Gas line", section: "Utilities"),
    ]

    static var sections: [(String, [SiteTag])] {
        let grouped = Dictionary(grouping: all) { $0.section }
        let order = ["Access & Delivery", "Site Status", "Existing Conditions", "Floor & Wall", "Utilities"]
        return order.compactMap { section in
            guard let items = grouped[section] else { return nil }
            return (section, items)
        }
    }

    static func label(for key: String) -> String? {
        all.first { $0.id == key }?.label
    }
}
