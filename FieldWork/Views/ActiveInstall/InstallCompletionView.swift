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
                    // Summary
                    summarySection

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
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Complete Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
                        .foregroundStyle(.green)
                    Text("Installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.flaggedCount > 0 {
                    VStack {
                        Text("\(viewModel.flaggedCount)")
                            .font(.title.bold())
                            .foregroundStyle(.orange)
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
                            .foregroundStyle(.gray)
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
            if viewModel.booking.signatureCaptured {
                Label("Signature captured", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else if viewModel.signatureLinkSent {
                Label("Signature link sent — pending", systemImage: "paperplane.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            } else {
                Label("No signature collected", systemImage: "pencil.slash")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Flagged Surfaces

    private var flaggedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("\(viewModel.flaggedCount) surface\(viewModel.flaggedCount == 1 ? "" : "s") flagged")
                    .font(.subheadline.bold())
            }

            Text("Service call records will be auto-generated for flagged surfaces.")
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
                                    .foregroundStyle(resp == "fabricator" ? .red : .orange)
                            }
                            if let reason = status?.reasonCode {
                                Text(reason.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if status?.status == "partial" {
                            StatusBadge(text: "Partial", color: .orange)
                        } else {
                            StatusBadge(text: "Not Installed", color: .red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Confirm

    private var confirmButton: some View {
        Button {
            Task {
                await viewModel.completeVisit(context: modelContext)
                if viewModel.booking.visitStatus == "completed" {
                    dismiss()
                }
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
        .tint(viewModel.flaggedCount > 0 ? .orange : .green)
        .disabled(viewModel.isCompleting)
    }
}
