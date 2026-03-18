import SwiftUI
import SwiftData

struct PartialVisitSheet: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Partial Completion")
                            .font(.title2.bold())
                        Text("Some surfaces weren't measured. Please provide a reason for each skipped surface.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Surface status list
                    ForEach(viewModel.booking.measurements, id: \.measurementId) { measurement in
                        let surface = viewModel.booking.surfaces.first { $0.surfaceId == measurement.surfaceId }
                        SurfaceSkipRow(
                            surfaceName: surface?.displayName ?? "Surface",
                            measurement: measurement
                        )
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completion Notes")
                            .font(.subheadline.bold())
                        TextField("Any additional notes...", text: $viewModel.completionNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }

                    // Confirm
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
                            Text("Complete as Partial")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(viewModel.isCompleting || !viewModel.allSkippedHaveReasons)

                    if !viewModel.allSkippedHaveReasons {
                        Text("Please provide a skip reason for all unmeasured surfaces.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Partial Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct SurfaceSkipRow: View {
    let surfaceName: String
    @Bindable var measurement: CachedMeasurement

    private let skipReasons: [(String, String)] = [
        ("cabinet_not_installed", "Cabinet not installed"),
        ("cabinets_not_level", "Cabinets not level"),
        ("surface_inaccessible", "Surface inaccessible"),
        ("customer_asked_stop", "Customer asked to stop"),
        ("ran_out_of_time", "Ran out of time"),
        ("equipment_issue", "Equipment issue"),
        ("other", "Other"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(surfaceName)
                    .font(.subheadline.bold())
                Spacer()
                if measurement.isMeasured {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Skipped", systemImage: "forward.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if !measurement.isMeasured {
                Picker("Skip Reason", selection: Binding(
                    get: { measurement.skipReason ?? "" },
                    set: { newValue in
                        measurement.skipReason = newValue.isEmpty ? nil : newValue
                        measurement.status = "skipped"
                    }
                )) {
                    Text("Select reason...").tag("")
                    ForEach(skipReasons, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .tint(.orange)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
