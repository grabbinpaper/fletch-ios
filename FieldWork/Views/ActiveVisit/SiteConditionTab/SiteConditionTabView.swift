import SwiftUI
import SwiftData

struct SiteConditionTabView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showCamera = false

    private var isReadOnly: Bool {
        viewModel.booking.visitStatus == "completed"
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(SiteConditions.sections, id: \.0) { section, definitions in
                    // Section header
                    Text(section)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    ForEach(definitions) { definition in
                        if let condition = viewModel.siteCondition(for: definition.id) {
                            SiteConditionRow(
                                definition: definition,
                                condition: condition,
                                isReadOnly: isReadOnly,
                                onStatusChange: { status in
                                    viewModel.updateSiteCondition(
                                        condition,
                                        status: status,
                                        context: modelContext
                                    )
                                },
                                onDetailChange: { value in
                                    viewModel.updateSiteCondition(
                                        condition,
                                        detailValue: value,
                                        context: modelContext
                                    )
                                },
                                onCameraTap: {
                                    viewModel.pendingSiteConditionKey = definition.id
                                    showCamera = true
                                }
                            )
                        }
                    }
                }

                // Completion warning
                if viewModel.flaggedConditionsMissingPhotos > 0 && !isReadOnly {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(viewModel.flaggedConditionsMissingPhotos) flagged condition(s) need photos before completing visit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                viewModel.capturePhoto(
                    image: image,
                    context: modelContext
                )
            }
        }
    }
}

// MARK: - Condition Row

struct SiteConditionRow: View {
    let definition: SiteConditionDefinition
    let condition: CachedSiteCondition
    let isReadOnly: Bool
    let onStatusChange: (String) -> Void
    let onDetailChange: (String) -> Void
    let onCameraTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: status dot, label, photo count badge, camera button, status menu
            HStack(spacing: 8) {
                statusDot
                    .frame(width: 10, height: 10)

                Text(definition.label)
                    .font(.subheadline)

                Spacer()

                if condition.photoCount > 0 {
                    Text("\(condition.photoCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.blue, in: Circle())
                }

                if isFlagged && !isReadOnly {
                    Button(action: onCameraTap) {
                        Image(systemName: "camera.fill")
                            .font(.subheadline)
                            .foregroundStyle(needsPhoto ? .orange : .blue)
                    }
                }

                if !isReadOnly {
                    Menu {
                        Button { onStatusChange("no_issue") } label: {
                            Label("No Issue", systemImage: "checkmark.circle")
                        }
                        Button { onStatusChange("concern") } label: {
                            Label("Concern", systemImage: "exclamationmark.triangle")
                        }
                        Button { onStatusChange("problem") } label: {
                            Label("Problem", systemImage: "xmark.octagon")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Detail field
            detailField

            // Photo required warning
            if needsPhoto && !isReadOnly {
                Label("Photo required", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 18)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var isFlagged: Bool {
        condition.status == "concern" || condition.status == "problem"
    }

    private var needsPhoto: Bool {
        isFlagged && condition.photoCount == 0
    }

    @ViewBuilder
    private var statusDot: some View {
        Circle()
            .fill(statusColor)
    }

    private var statusColor: Color {
        switch condition.status {
        case "concern": return .yellow
        case "problem": return .red
        default: return .green
        }
    }

    @ViewBuilder
    private var detailField: some View {
        switch definition.detailFieldType {
        case .picker(let options):
            if isReadOnly {
                if let value = condition.detailValue, !value.isEmpty {
                    Text("\(definition.detailLabel): \(value)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 18)
                }
            } else {
                Picker(definition.detailLabel, selection: pickerBinding) {
                    Text("—").tag("")
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
                .padding(.leading, 10)
            }

        case .intStepper(let label, let range):
            HStack(spacing: 8) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isReadOnly {
                    Text(condition.detailValue ?? "0")
                        .font(.caption.monospacedDigit())
                } else {
                    Stepper(
                        value: stepperBinding(range: range),
                        in: range
                    ) {
                        Text("\(stepperValue)")
                            .font(.caption.monospacedDigit())
                    }
                }
            }
            .padding(.leading, 18)

        case .boolToggle:
            if isReadOnly {
                if let value = condition.detailValue {
                    Text("\(definition.detailLabel): \(value)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 18)
                }
            } else {
                Toggle(definition.detailLabel, isOn: toggleBinding)
                    .font(.caption)
                    .padding(.leading, 18)
                    .padding(.trailing, 4)
            }
        }
    }

    private var pickerBinding: Binding<String> {
        Binding(
            get: { condition.detailValue ?? "" },
            set: { onDetailChange($0) }
        )
    }

    private var stepperValue: Int {
        Int(condition.detailValue ?? "0") ?? 0
    }

    private func stepperBinding(range: ClosedRange<Int>) -> Binding<Int> {
        Binding(
            get: { stepperValue },
            set: { onDetailChange("\($0)") }
        )
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { condition.detailValue == "Yes" },
            set: { onDetailChange($0 ? "Yes" : "No") }
        )
    }
}
