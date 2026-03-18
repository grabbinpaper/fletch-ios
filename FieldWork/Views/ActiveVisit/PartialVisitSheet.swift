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

                    // Return visit warning
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Return visit required")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                            Text("The office will schedule a return visit for skipped surfaces.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Blockers section
                    if !viewModel.completionBlockers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Requirements Not Met", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)

                            ForEach(viewModel.completionBlockers) { blocker in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    Text(blocker.message)
                                        .font(.caption)
                                }
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Surface status list
                    ForEach(viewModel.booking.measurements, id: \.measurementId) { measurement in
                        let surface = viewModel.booking.surfaces.first { $0.surfaceId == measurement.surfaceId }
                        SurfaceSkipRow(
                            surfaceName: surface?.displayName ?? "Surface",
                            measurement: measurement
                        )
                    }

                    // Signature note
                    if viewModel.requiresSignature {
                        HStack(spacing: 10) {
                            Image(systemName: "signature")
                                .foregroundStyle(.blue)
                            Text("Signature link will be sent to the customer after completion.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

                    // Confirm
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
                            Text("Complete as Partial")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(viewModel.isCompleting || !viewModel.allSkippedHaveReasons || !viewModel.completionBlockers.isEmpty)

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
        ("denied_access", "Denied access"),
        ("cabinet_not_installed", "Cabinet not installed"),
        ("cabinets_not_level", "Cabinets not level"),
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
