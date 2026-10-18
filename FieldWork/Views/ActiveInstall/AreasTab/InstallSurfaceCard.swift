import SwiftUI
import SwiftData

struct InstallSurfaceCard: View {
    let surface: CachedSurface
    let surfaceStatus: CachedSurfaceStatus?
    var viewModel: ActiveInstallViewModel
    var onCamera: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded = false
    @State private var selectedResponsibility: IssueResponsibility = .fabricator
    @State private var selectedReasonCode: String?
    @State private var issueNotes = ""

    private var currentStatus: String {
        surfaceStatus?.status ?? "pending"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible
            header
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

            if isExpanded {
                Divider()
                expandedContent
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // Load existing issue details
            if let status = surfaceStatus {
                if let resp = status.responsibility {
                    selectedResponsibility = resp == "customer" ? .customer : .fabricator
                }
                selectedReasonCode = status.reasonCode
                issueNotes = status.notes ?? ""
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(surface.displayName)
                    .font(.subheadline.bold())
                if surface.installStatus == "installed" {
                    Text("Installed on an earlier day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let earlier = surface.installStatus {
                    Text(earlier == "partial" ? "Partly installed on an earlier day" : "Not installed on an earlier day")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Status indicator
            statusBadge

            // Camera shortcut
            if let onCamera {
                Button(action: onCamera) {
                    Image(systemName: "camera.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.blue)
                        .clipShape(Circle())
                }
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch currentStatus {
        case "installed":
            StatusBadge(text: "Installed", color: .green)
        case "partial":
            StatusBadge(text: "Partial", color: .orange)
        case "not_installed":
            StatusBadge(text: "Not Installed", color: .red)
        default:
            StatusBadge(text: "Pending", color: .gray)
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Installation Status")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    statusButton("Installed", status: "installed", icon: "checkmark.circle.fill", color: .green)
                    statusButton("Partial", status: "partial", icon: "exclamationmark.triangle.fill", color: .orange)
                    statusButton("Not Installed", status: "not_installed", icon: "xmark.circle.fill", color: .red)
                }
            }

            // Issue section — shown when Partial or Not Installed
            if currentStatus == "partial" || currentStatus == "not_installed" {
                issueSection
            }

            // Surface info
            if let sqft = surface.estimatedSqft {
                HStack {
                    Label(String(format: "%.0f sqft quoted", sqft), systemImage: "square.dashed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private func statusButton(_ label: String, status: String, icon: String, color: Color) -> some View {
        Button {
            viewModel.setStatus(status, for: surface.surfaceId, context: modelContext)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(currentStatus == status ? color.opacity(0.2) : Color.clear)
            .foregroundStyle(currentStatus == status ? color : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(currentStatus == status ? color : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Issue Section

    private var issueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            // Responsibility selector
            Text("Responsibility")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(IssueResponsibility.allCases) { resp in
                    Button {
                        selectedResponsibility = resp
                        selectedReasonCode = nil
                        syncIssueDetails()
                    } label: {
                        Text(resp.label)
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedResponsibility == resp ? responsibilityColor(resp).opacity(0.2) : Color.clear)
                            .foregroundStyle(selectedResponsibility == resp ? responsibilityColor(resp) : .secondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedResponsibility == resp ? responsibilityColor(resp) : Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Reason codes
            Text("Reason")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            let reasons = viewModel.issueReasons(for: selectedResponsibility)
            if reasons.isEmpty {
                Text("No issue reasons loaded. Connect to the internet, or ask the office to add them in Settings → Issue codes.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            ForEach(reasons) { reason in
                let picked = selectedReasonCode == reason.id.uuidString
                Button {
                    selectedReasonCode = reason.id.uuidString
                    syncIssueDetails()
                } label: {
                    HStack {
                        Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(picked ? .blue : .secondary)
                        Text(reason.label)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }

            if viewModel.issueReason(id: selectedReasonCode)?.requiresPhoto == true {
                Label("Take a photo of this with the camera button", systemImage: "camera")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            // Notes
            Text(currentStatus == "not_installed" ? "Notes (required)" : "Notes")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            TextField("Describe the issue...", text: $issueNotes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .onChange(of: issueNotes) { _, _ in
                    syncIssueDetails()
                }
        }
    }

    private func responsibilityColor(_ resp: IssueResponsibility) -> Color {
        switch resp {
        case .fabricator: return .red
        case .customer: return .orange
        }
    }

    private func syncIssueDetails() {
        viewModel.setIssueDetails(
            for: surface.surfaceId,
            responsibility: selectedResponsibility.rawValue,
            reasonCode: selectedReasonCode,
            notes: issueNotes.isEmpty ? nil : issueNotes,
            context: modelContext
        )
    }
}
