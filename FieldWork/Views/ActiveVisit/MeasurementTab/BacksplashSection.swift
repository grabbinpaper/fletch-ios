import SwiftUI

struct BacksplashSection: View {
    let backsplashMeasurements: [CachedBacksplashMeasurement]
    let isReadOnly: Bool
    let onSave: (CachedBacksplashMeasurement) -> Void
    let onAdd: (BacksplashFormData) -> Void
    let onRemove: (CachedBacksplashMeasurement) -> Void

    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Splash")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if !backsplashMeasurements.isEmpty {
                    Text("(\(backsplashMeasurements.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !isReadOnly {
                    Button { showAddSheet = true } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Splash")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }

            if backsplashMeasurements.isEmpty {
                Text("No splash pieces")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(backsplashMeasurements, id: \.backsplashMeasurementId) { bm in
                BacksplashMeasurementRow(
                    bm: bm,
                    isReadOnly: isReadOnly,
                    onSave: { onSave(bm) },
                    onRemove: bm.source == "field" ? { onRemove(bm) } : nil
                )
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddBacksplashSheet { data in
                onAdd(data)
            }
        }
    }
}

// MARK: - Row

private struct BacksplashMeasurementRow: View {
    let bm: CachedBacksplashMeasurement
    let isReadOnly: Bool
    let onSave: () -> Void
    var onRemove: (() -> Void)?

    @State private var heightText = ""
    @State private var lengthText = ""
    @State private var finishedEnds: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(bm.displayLocation)
                    .font(.subheadline.bold())
                StatusBadge(
                    text: bm.source == "quoted" ? "Quoted" : "Field",
                    color: bm.source == "quoted" ? .blue : .purple
                )
                Spacer()
                if let onRemove, !isReadOnly {
                    Button(role: .destructive) { onRemove() } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
            }

            // Quoted reference
            if let qH = bm.quotedHeightIn, let qL = bm.quotedLengthIn {
                Text("Quoted: \(formatDim(qH))H \u{00D7} \(formatDim(qL))L")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Actual measurement fields
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Height")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 2) {
                        TextField("0", text: $heightText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 60)
                            .disabled(isReadOnly)
                            .onChange(of: heightText) {
                                heightText = filterNum(heightText)
                                let val = Double(heightText)
                                guard val != bm.actualHeightIn else { return }
                                bm.actualHeightIn = val
                                onSave()
                            }
                        Text("\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Length")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 2) {
                        TextField("0", text: $lengthText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 60)
                            .disabled(isReadOnly)
                            .onChange(of: lengthText) {
                                lengthText = filterNum(lengthText)
                                let val = Double(lengthText)
                                guard val != bm.actualLengthIn else { return }
                                bm.actualLengthIn = val
                                onSave()
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fin. Ends")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Stepper("\(finishedEnds)", value: $finishedEnds, in: 0...2)
                        .font(.caption)
                        .disabled(isReadOnly)
                        .onChange(of: finishedEnds) {
                            guard finishedEnds != bm.finishedEnds else { return }
                            bm.finishedEnds = finishedEnds
                            onSave()
                        }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            heightText = bm.actualHeightIn.map { formatVal($0) } ?? ""
            lengthText = bm.actualLengthIn.map { formatVal($0) } ?? ""
            finishedEnds = bm.finishedEnds
        }
    }

    private func formatDim(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))\""
        }
        return String(format: "%.2f\"", value)
    }

    private func formatVal(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.2f", value)
    }

    private func filterNum(_ text: String) -> String {
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
}

struct BacksplashFormData {
    let location: String
    let heightIn: Double?
    let lengthIn: Double?
}
