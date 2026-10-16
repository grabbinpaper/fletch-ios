import Foundation
import SwiftData

// MARK: - Surface Install Status

@Model
final class CachedSurfaceStatus {
    @Attribute(.unique) var surfaceStatusId: UUID
    var visitId: UUID
    var surfaceId: UUID
    var status: String // pending, installed, partial, not_installed
    var responsibility: String? // fabricator, customer — only when status != installed
    var reasonCode: String? // issue reason code key
    var notes: String?

    init(visitId: UUID, surfaceId: UUID) {
        self.surfaceStatusId = UUID()
        self.visitId = visitId
        self.surfaceId = surfaceId
        self.status = "pending"
    }
}

// MARK: - Issue Reason Codes

enum IssueResponsibility: String, CaseIterable, Identifiable {
    case fabricator = "fabricator"
    case customer = "customer"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fabricator: return "Our Issue"
        case .customer: return "Customer Issue"
        }
    }
}

struct IssueReasonCode: Identifiable {
    let id: String
    let label: String
    let responsibility: IssueResponsibility
}

enum IssueReasonCodes {
    static let fabricatorReasons: [IssueReasonCode] = [
        IssueReasonCode(id: "not_loaded", label: "Piece not loaded / forgotten at shop", responsibility: .fabricator),
        IssueReasonCode(id: "damaged_transport", label: "Piece damaged in transport", responsibility: .fabricator),
        IssueReasonCode(id: "cut_incorrectly", label: "Piece cut incorrectly", responsibility: .fabricator),
        IssueReasonCode(id: "wrong_material", label: "Wrong material or color", responsibility: .fabricator),
        IssueReasonCode(id: "edge_incorrect", label: "Edge profile incorrect", responsibility: .fabricator),
        IssueReasonCode(id: "too_short", label: "Piece too short / doesn't fit", responsibility: .fabricator),
    ]

    static let customerReasons: [IssueReasonCode] = [
        IssueReasonCode(id: "cabinets_not_ready", label: "Cabinets not installed / not ready", responsibility: .customer),
        IssueReasonCode(id: "cabinets_not_level", label: "Cabinets not level", responsibility: .customer),
        IssueReasonCode(id: "tearout_incomplete", label: "Tearout not complete", responsibility: .customer),
        IssueReasonCode(id: "appliances_not_removed", label: "Appliances not removed", responsibility: .customer),
        IssueReasonCode(id: "plumbing_not_capped", label: "Plumbing not capped", responsibility: .customer),
        IssueReasonCode(id: "electrical_in_way", label: "Electrical in the way", responsibility: .customer),
        IssueReasonCode(id: "site_not_accessible", label: "Site not accessible", responsibility: .customer),
    ]

    static func reasons(for responsibility: IssueResponsibility) -> [IssueReasonCode] {
        switch responsibility {
        case .fabricator: return fabricatorReasons
        case .customer: return customerReasons
        }
    }
}
