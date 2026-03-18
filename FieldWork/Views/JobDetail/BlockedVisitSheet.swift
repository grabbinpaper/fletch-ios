import SwiftUI

struct BlockedVisitSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onReport: (BlockedReason, String?) -> Void

    @State private var selectedReason: BlockedReason?
    @State private var notes = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Select a reason why this visit can't be completed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section("Reason") {
                    ForEach(BlockedReason.allCases) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Image(systemName: reason.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(reason.iconColor)
                                Text(reason.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                Section("Notes (optional)") {
                    TextField("Additional details...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        guard let reason = selectedReason else { return }
                        isSubmitting = true
                        onReport(reason, notes.isEmpty ? nil : notes)
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Report Blocked")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(selectedReason == nil || isSubmitting)
                    .listRowBackground(
                        (selectedReason != nil && !isSubmitting) ? Color.red : Color.red.opacity(0.3)
                    )
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle("Can't Complete Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Blocked Reason

enum BlockedReason: String, CaseIterable, Identifiable {
    case noSiteAccess = "no_site_access"
    case customerNotHome = "customer_not_home"
    case siteNotReady = "site_not_ready"
    case safetyHazard = "safety_hazard"
    case wrongAddress = "wrong_address"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noSiteAccess: return "No site access"
        case .customerNotHome: return "Customer not home"
        case .siteNotReady: return "Site not ready"
        case .safetyHazard: return "Safety hazard"
        case .wrongAddress: return "Wrong address"
        }
    }

    var icon: String {
        switch self {
        case .noSiteAccess: return "lock.fill"
        case .customerNotHome: return "person.slash.fill"
        case .siteNotReady: return "hammer.fill"
        case .safetyHazard: return "exclamationmark.triangle.fill"
        case .wrongAddress: return "mappin.slash"
        }
    }

    var iconColor: Color {
        switch self {
        case .noSiteAccess: return .orange
        case .customerNotHome: return .blue
        case .siteNotReady: return .purple
        case .safetyHazard: return .red
        case .wrongAddress: return .gray
        }
    }
}
