import Foundation
import SwiftData
import Supabase

// MARK: - Surface Install Status

@Model
final class CachedSurfaceStatus {
    @Attribute(.unique) var surfaceStatusId: UUID
    var visitId: UUID
    var surfaceId: UUID
    var status: String // pending, installed, partial, not_installed
    var responsibility: String? // fabricator, customer — only when status != installed
    var reasonCode: String? // issue_reason_code.reason_code_id (uuid string)
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

/// One of the shop's issue reasons (Settings -> Field Operations -> Issue codes).
struct IssueReasonCode: Identifiable, Codable, Hashable {
    let id: UUID
    let code: String
    let label: String
    let responsibility: String
    let requiresPhoto: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "reason_code_id"
        case code, label, responsibility
        case requiresPhoto = "requires_photo"
    }
}

/// The shop's issue reasons for install visits: active codes for any visit type plus install-only
/// ones. Loaded from the server and kept on the phone for offline use.
enum IssueReasonCodes {
    private static let cacheKey = "installIssueReasons"

    static var cached: [IssueReasonCode] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return [] }
        return (try? JSONDecoder().decode([IssueReasonCode].self, from: data)) ?? []
    }

    @MainActor
    static func load(appState: AppState) async -> [IssueReasonCode] {
        guard appState.networkMonitor.isConnected, let orgId = appState.organizationId else { return cached }
        do {
            let codes: [IssueReasonCode] = try await appState.supabaseManager.client
                .from("issue_reason_code")
                .select("reason_code_id, code, label, responsibility, requires_photo")
                .eq("organization_id", value: orgId.uuidString)
                .eq("is_active", value: true)
                .or("applies_to.is.null,applies_to.cs.{install}")
                .order("display_order")
                .execute()
                .value
            if let data = try? JSONEncoder().encode(codes) {
                UserDefaults.standard.set(data, forKey: cacheKey)
            }
            return codes
        } catch {
            return cached
        }
    }
}
