import SwiftUI
import SwiftData

struct MeasurementTabView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                    SurfaceMeasurementCard(
                        surface: surface,
                        isReadOnly: viewModel.booking.visitStatus == "completed",
                        onUpdate: { length, width, notes in
                            viewModel.updateMeasurement(
                                surface: surface,
                                length: length,
                                width: width,
                                notes: notes,
                                context: modelContext
                            )
                        }
                    )
                }
            }
            .padding()
        }
    }
}

private func formatInchesDisplay(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return "\(Int(value))\""
    }
    return String(format: "%.2f\"", value)
}

struct SurfaceMeasurementCard: View {
    let surface: CachedSurface
    let isReadOnly: Bool
    let onUpdate: (Double?, Double?, String?) -> Void

    @State private var lengthText: String = ""
    @State private var widthText: String = ""
    @State private var notesText: String = ""
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(surface.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        if let material = surface.materialName {
                            Text(material)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if surface.actualLengthInches != nil && surface.actualWidthInches != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isExpanded {
                // Estimated dimensions (read-only)
                if let estL = surface.estimatedLengthInches, let estW = surface.estimatedWidthInches {
                    HStack {
                        Text("Estimated:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(formatInchesDisplay(estL)) x \(formatInchesDisplay(estW))")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        if let sqft = surface.estimatedSqft {
                            Text("(\(String(format: "%.1f", sqft)) sqft)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Actual dimensions input
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Length (in)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            TextField("0", text: $lengthText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 80)
                                .disabled(isReadOnly)
                                .onChange(of: lengthText) {
                                    lengthText = filterNumeric(lengthText)
                                    commitMeasurements()
                                }
                            Text("\"")
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Width (in)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            TextField("0", text: $widthText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 80)
                                .disabled(isReadOnly)
                                .onChange(of: widthText) {
                                    widthText = filterNumeric(widthText)
                                    commitMeasurements()
                                }
                            Text("\"")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Auto sqft
                    if let sqft = calculatedSqft {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Sqft")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", sqft))
                                .font(.title3.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Backsplash pieces
                if surface.hasBacksplash && !surface.backsplashPieces.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Backsplash Pieces")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(surface.backsplashPieces, id: \.surfaceBacksplashId) { piece in
                            HStack {
                                Text("\(formatInchesDisplay(piece.heightInches))H x \(formatInchesDisplay(piece.lengthInches))L")
                                    .font(.caption)
                                Text("\(piece.finishedEnds) finished end(s)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("Template Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Notes...", text: $notesText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .disabled(isReadOnly)
                        .onChange(of: notesText) { commitMeasurements() }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            lengthText = surface.actualLengthInches.map { formatValue($0) } ?? ""
            widthText = surface.actualWidthInches.map { formatValue($0) } ?? ""
            notesText = surface.templateNotes ?? ""
        }
    }

    private var calculatedSqft: Double? {
        guard let l = Double(lengthText), let w = Double(widthText), l > 0, w > 0 else { return nil }
        return (l * w) / 144.0
    }

    private func commitMeasurements() {
        let length = Double(lengthText)
        let width = Double(widthText)
        let notes = notesText.isEmpty ? nil : notesText
        onUpdate(length, width, notes)
    }

    private func filterNumeric(_ text: String) -> String {
        var result = ""
        var hasDecimal = false
        for char in text {
            if char.isNumber {
                result.append(char)
            } else if char == "." && !hasDecimal {
                hasDecimal = true
                result.append(char)
            }
        }
        return result
    }

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.2f", value)
    }
}
