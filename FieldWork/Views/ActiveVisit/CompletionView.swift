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

                    // Measurements summary
                    summarySection(
                        title: "Measurements",
                        icon: "ruler",
                        status: measurementStatus
                    ) {
                        ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                            HStack {
                                Text(surface.displayName)
                                    .font(.caption)
                                Spacer()
                                if let l = surface.actualLengthInches, let w = surface.actualWidthInches {
                                    Text("\(formatInches(l)) x \(formatInches(w))")
                                        .font(.caption.bold())
                                }
                                Image(systemName: surface.actualLengthInches != nil ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(surface.actualLengthInches != nil ? .green : .secondary)
                                    .font(.caption)
                            }
                        }
                    }

                    // Photos summary
                    summarySection(
                        title: "Photos",
                        icon: "camera",
                        status: "\(viewModel.photos.count) captured"
                    ) {
                        EmptyView()
                    }

                    // Checklist summary
                    if !viewModel.checklistItems.isEmpty {
                        let completed = viewModel.checklistItems.filter { $0.status != "pending" }.count
                        summarySection(
                            title: "Checklist",
                            icon: "checklist",
                            status: "\(completed)/\(viewModel.checklistItems.count) items"
                        ) {
                            EmptyView()
                        }
                    }

                    // Signature
                    if viewModel.booking.signatureRequired {
                        summarySection(
                            title: "Signature",
                            icon: "signature",
                            status: viewModel.booking.signatureCaptured ? "Captured" : "Missing"
                        ) {
                            EmptyView()
                        }
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
                            dismiss()
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
                    .disabled(viewModel.isCompleting || !viewModel.canComplete)

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
        let total = viewModel.booking.surfaces.count
        let measured = viewModel.booking.surfaces.filter {
            $0.actualLengthInches != nil && $0.actualWidthInches != nil
        }.count
        return "\(measured)/\(total) surfaces"
    }

    @ViewBuilder
    private func summarySection<Content: View>(
        title: String,
        icon: String,
        status: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                Spacer()
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
