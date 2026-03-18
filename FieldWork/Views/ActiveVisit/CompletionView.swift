import SwiftUI
import SwiftData

struct CompletionView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visit Summary")
                            .font(.title2.bold())
                        if let jobNumber = viewModel.booking.jobNumber {
                            Text("Job #\(jobNumber)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Blockers section
                    if !viewModel.completionBlockers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Requirements Not Met", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)

                            ForEach(viewModel.completionBlockers) { blocker in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: blockerIcon(for: blocker.ruleType))
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .frame(width: 16)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(blocker.message)
                                            .font(.caption)
                                        if !blocker.targetLabel.isEmpty {
                                            Text(blocker.targetLabel)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.red.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Measurements summary
                    summarySection(
                        title: "Measurements",
                        icon: "ruler",
                        status: measurementStatus,
                        isComplete: viewModel.isAllMeasured
                    ) {
                        ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                            let measurement = viewModel.booking.measurement(for: surface.surfaceId)
                            HStack {
                                Text(surface.displayName)
                                    .font(.caption)
                                Spacer()
                                if let l = measurement?.actualLengthIn, let w = measurement?.actualWidthIn {
                                    Text("\(formatInches(l)) x \(formatInches(w))")
                                        .font(.caption.bold())
                                }
                                if measurement?.hasDimensionChange == true {
                                    StatusBadge(text: "Changed", color: .orange)
                                }
                                Image(systemName: measurement?.isMeasured == true ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(measurement?.isMeasured == true ? .green : .secondary)
                                    .font(.caption)
                            }
                        }
                    }

                    // Photos summary
                    summarySection(
                        title: "Photos",
                        icon: "camera",
                        status: "\(viewModel.photos.count) captured",
                        isComplete: !hasBlocker("photo_per_surface") && !hasBlocker("photo_site")
                    ) {
                        EmptyView()
                    }

                    // Checklist summary
                    if !viewModel.checklistItems.isEmpty {
                        let completed = viewModel.checklistItems.filter { $0.status != "pending" }.count
                        summarySection(
                            title: "Checklist",
                            icon: "checklist",
                            status: "\(completed)/\(viewModel.checklistItems.count) items",
                            isComplete: !hasBlocker("checklist_complete")
                        ) {
                            EmptyView()
                        }
                    }

                    // Signature info
                    if viewModel.requiresSignature {
                        HStack(spacing: 10) {
                            Image(systemName: "signature")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Signature link will be sent")
                                    .font(.subheadline.bold())
                                Text("The customer will receive a text/email to review and sign after you complete.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completion Notes")
                            .font(.subheadline.bold())
                        TextField("Any additional notes...", text: $viewModel.completionNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }

                    // Confirm button
                    Button {
                        Task {
                            await viewModel.completeVisit(context: modelContext)
                            if viewModel.error == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isCompleting {
                            ProgressView()
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
                    .tint(.green)
                    .disabled(viewModel.isCompleting || !viewModel.completionBlockers.isEmpty)

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

    private var measurementStatus: String {
        let total = viewModel.totalMeasurementCount
        let measured = viewModel.measuredCount
        return "\(measured)/\(total) surfaces"
    }

    private func hasBlocker(_ ruleType: String) -> Bool {
        viewModel.completionBlockers.contains { $0.ruleType == ruleType }
    }

    private func blockerIcon(for ruleType: String) -> String {
        switch ruleType {
        case "photo_per_surface", "photo_site": return "camera"
        case "surface_dimensions", "backsplash_dimensions": return "ruler"
        case "checklist_complete": return "checklist"
        case "no_blocking_issues": return "exclamationmark.octagon"
        default: return "xmark.circle"
        }
    }

    @ViewBuilder
    private func summarySection<Content: View>(
        title: String,
        icon: String,
        status: String,
        isComplete: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isComplete ? .green : .secondary)
                        .font(.caption)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatInches(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))\""
        }
        return String(format: "%.1f\"", value)
    }
}
