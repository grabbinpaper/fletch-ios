import SwiftUI
import SwiftData

struct InstallCompletionView: View {
    @Bindable var viewModel: ActiveInstallViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let result = viewModel.completionResult {
                        resultSection(result)
                    } else {
                    // Summary
                    summarySection

                    // Unmarked surfaces
                    if viewModel.unmarkedCount > 0 {
                        unmarkedSection
                    }

                    // Flagged surfaces
                    if viewModel.flaggedCount > 0 {
                        flaggedSection
                    }

                    // Notes
                    notesSection

                    // Confirm button
                    confirmButton

                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.sfDanger)
                    }
                    }
                }
                .padding()
            }
            .navigationTitle("Complete Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.completionResult == nil {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.completionResult != nil {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Installation Summary", systemImage: "checklist")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                VStack {
                    Text("\(viewModel.installedCount)")
                        .font(.title.bold())
                        .foregroundStyle(.sfSuccess)
                    Text("Installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.flaggedCount > 0 {
                    VStack {
                        Text("\(viewModel.flaggedCount)")
                            .font(.title.bold())
                            .foregroundStyle(.sfWarning)
                        Text("Flagged")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                let pendingCount = viewModel.totalSurfaceCount - viewModel.confirmedCount
                if pendingCount > 0 {
                    VStack {
                        Text("\(pendingCount)")
                            .font(.title.bold())
                            .foregroundStyle(.sfInkMuted)
                        Text("Pending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Photos count
            Label("\(viewModel.photos.count) photos captured", systemImage: "photo.stack")
                .font(.subheadline)

            // Signature status
            if !viewModel.booking.signatureRequired {
                Label("No sign-off needed for this job", systemImage: "checkmark.seal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !viewModel.signOffAllowed {
                Label("Sign-off comes when the work is finished — no customer signature on this visit",
                      systemImage: "signature")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if viewModel.booking.signatureCaptured {
                Label("Signature captured", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(.sfSuccess)
            } else if viewModel.signatureMode == .remote {
                if let how = viewModel.linkTargetsDescription {
                    Label("Sign-off link will be \(how) when you finish", systemImage: "paperplane.fill")
                        .font(.subheadline)
                        .foregroundStyle(.sfInkMuted)
                } else {
                    Label("No phone or email picked — go back to the Sign tab to choose where the link goes",
                          systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.sfWarning)
                }
            } else {
                Label("Customer hasn't signed — the office can send them the link", systemImage: "pencil.slash")
                    .font(.subheadline)
                    .foregroundStyle(.sfWarning)
            }
        }
        .padding()
        .sfCard()
    }

    // MARK: - Flagged Surfaces

    private var flaggedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.sfWarning)
                Text("\(viewModel.flaggedCount) surface\(viewModel.flaggedCount == 1 ? "" : "s") flagged")
                    .font(.subheadline.bold())
            }

            Text("Each flagged surface goes to the office's Exceptions queue.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                let status = viewModel.status(for: surface.surfaceId)
                if status?.status == "partial" || status?.status == "not_installed" {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(surface.displayName)
                                .font(.subheadline)
                            if let resp = status?.responsibility {
                                Text(resp == "fabricator" ? "Our Issue" : "Customer Issue")
                                    .font(.caption)
                                    .foregroundStyle(resp == "fabricator" ? .sfDanger : .sfWarning)
                            }
                            if let reason = viewModel.issueReason(id: status?.reasonCode) {
                                Text(reason.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if status?.status == "partial" {
                            StatusBadge(text: "Partial", color: .sfWarning)
                        } else {
                            StatusBadge(text: "Not Installed", color: .sfDanger)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.sfWarning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Unmarked Surfaces

    private var unmarkedSection: some View {
        let n = viewModel.unmarkedCount
        let surfaces = "\(n) surface\(n == 1 ? "" : "s")"
        return VStack(alignment: .leading, spacing: 6) {
            Label("\(surfaces) not marked", systemImage: "questionmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(viewModel.moreInstallDays ? Color.secondary : Color.sfDanger)
            Text(viewModel.moreInstallDays
                 ? "Another install day is booked — they carry over to it."
                 : "This is the last install day booked. Unmarked surfaces go to the office as problems and the job shows Install Incomplete.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background((viewModel.moreInstallDays ? Color.secondary : Color.sfDanger).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Result (after finishing)

    private func resultSection(_ result: CompleteInstallResult) -> some View {
        let issues = result.issuesCreated ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Label("Visit finished", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.sfSuccess)

            switch result.jobStatus {
            case "completed":
                Label("Job is complete", systemImage: "flag.checkered")
            case "install_incomplete":
                Label("Job is Install Incomplete", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.sfDanger)
            default:
                if result.lastInstallDay == false {
                    Label("More install days are booked — the job stays In Progress", systemImage: "calendar")
                }
            }

            if issues > 0 {
                Label("\(issues) problem\(issues == 1 ? "" : "s") sent to the office's Exceptions queue",
                      systemImage: "tray.full")
                    .foregroundStyle(.sfWarning)
            }

            if result.signatureNotAllowed == true {
                Label("The customer's signature wasn't kept — sign-off comes when the work is finished",
                      systemImage: "signature")
                    .foregroundStyle(.sfWarning)
            } else if viewModel.booking.signatureRequired && result.outcome != "accomplished" {
                Label("No sign-off yet — the customer signs when the work is finished", systemImage: "signature")
                    .foregroundStyle(.secondary)
            }

            if result.signaturePending == true {
                if viewModel.signatureLinkSent {
                    Label("Sign-off link sent", systemImage: "paperplane.fill")
                        .foregroundStyle(.sfInkMuted)
                } else {
                    Label("Customer still needs to sign off — send the link from the Sign tab, or the office can",
                          systemImage: "signature")
                        .foregroundStyle(.sfWarning)
                }
                if let err = viewModel.signoffError {
                    Text(err).font(.caption).foregroundStyle(.sfDanger)
                }
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .sfCard()
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Completion Notes", systemImage: "note.text")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            TextField("Any additional notes...", text: $viewModel.completionNotes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
        .padding()
        .sfCard()
    }

    // MARK: - Confirm

    private var confirmButton: some View {
        Button {
            Task {
                await viewModel.completeVisit(context: modelContext)
            }
        } label: {
            if viewModel.isCompleting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Completing...")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            } else {
                Text("Confirm & Complete")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.flaggedCount > 0 ? .sfWarning : .sfInk)
        .foregroundStyle(Color.sfOnFill)
        .disabled(viewModel.isCompleting)
    }
}
