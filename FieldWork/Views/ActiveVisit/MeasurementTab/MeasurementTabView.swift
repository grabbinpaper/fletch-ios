import SwiftUI
import SwiftData

struct MeasurementTabView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext
    var onCameraForSurface: ((UUID) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                    let measurement = viewModel.booking.measurement(for: surface.surfaceId)
                    SurfaceMeasurementCard(
                        surface: surface,
                        measurement: measurement,
                        edgeProfiles: viewModel.edgeProfiles,
                        isReadOnly: viewModel.booking.visitStatus == "completed",
                        onSave: {
                            if let m = measurement {
                                viewModel.saveMeasurement(m, context: modelContext)
                            }
                        },
                        onAddCutout: { data in
                            if let m = measurement {
                                viewModel.addCutout(data: data, measurement: m, context: modelContext)
                            }
                        },
                        onRemoveCutout: { cutout in
                            viewModel.removeCutout(cutout, context: modelContext)
                        },
                        onSaveBacksplash: {
                            if let m = measurement {
                                viewModel.saveMeasurement(m, context: modelContext)
                            }
                        },
                        onAddBacksplash: { data in
                            if let m = measurement {
                                viewModel.addBacksplash(data: data, measurement: m, context: modelContext)
                            }
                        },
                        onRemoveBacksplash: { bm in
                            viewModel.removeBacksplash(bm, context: modelContext)
                        },
                        onCamera: onCameraForSurface != nil ? {
                            onCameraForSurface?(surface.surfaceId)
                        } : nil
                    )
                }

                if viewModel.booking.visitStatus != "completed" {
                    Button { viewModel.showAddSurface = true } label: {
                        Label("Add Surface", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
        .onAppear { viewModel.loadEdgeProfiles() }
        .sheet(isPresented: $viewModel.showAddSurface) {
            AddSurfaceSheet(rooms: viewModel.availableRooms) { name, roomName in
                Task {
                    await viewModel.addFieldSurface(name: name, roomName: roomName, context: modelContext)
                }
            }
        }
    }
}

// MARK: - Helpers

private func formatInchesDisplay(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return "\(Int(value))\""
    }
    return String(format: "%.2f\"", value)
}

private func formatValue(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return "\(Int(value))"
    }
    return String(format: "%.2f", value)
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

private func parseSeamLocations(_ json: String?) -> [String] {
    guard let json, let data = json.data(using: .utf8),
          let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
    return arr
}

private func encodeSeamLocations(_ locations: [String]) -> String? {
    guard !locations.isEmpty else { return nil }
    guard let data = try? JSONEncoder().encode(locations) else { return nil }
    return String(data: data, encoding: .utf8)
}

// MARK: - Surface Measurement Card

struct SurfaceMeasurementCard: View {
    let surface: CachedSurface
    let measurement: CachedMeasurement?
    let edgeProfiles: [EdgeProfileOption]
    let isReadOnly: Bool
    let onSave: () -> Void
    let onAddCutout: (CutoutFormData) -> Void
    let onRemoveCutout: (CachedCutout) -> Void
    let onSaveBacksplash: () -> Void
    let onAddBacksplash: (BacksplashFormData) -> Void
    let onRemoveBacksplash: (CachedBacksplashMeasurement) -> Void
    var onCamera: (() -> Void)?

    // Dimensions
    @State private var lengthText = ""
    @State private var widthText = ""

    // Overhang
    @State private var overhangText = ""

    // Seams
    @State private var seamLocations: [String] = []

    // Finished edges
    @State private var finishedEdges = ""

    // Notes
    @State private var notesText = ""

    // UI state
    @State private var isExpanded = true
    @State private var showEdgeSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    quotedDimensions
                    actualDimensions

                    Divider()

                    edgeProfileSection

                    // Cutouts
                    if let measurement {
                        Divider()
                        CutoutSection(
                            cutouts: measurement.cutouts,
                            isReadOnly: isReadOnly,
                            onAdd: onAddCutout,
                            onRemove: onRemoveCutout
                        )
                    }

                    Divider()

                    overhangSection

                    Divider()

                    finishedEdgesSection

                    Divider()

                    // Backsplash per-piece measurements
                    if let measurement {
                        BacksplashSection(
                            backsplashMeasurements: measurement.backsplashMeasurements,
                            isReadOnly: isReadOnly,
                            onSave: { _ in onSaveBacksplash() },
                            onAdd: onAddBacksplash,
                            onRemove: onRemoveBacksplash
                        )
                    }

                    Divider()

                    seamSection

                    Divider()

                    notesSection
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear(perform: loadFields)
        .sheet(isPresented: $showEdgeSheet) {
            EdgeProfileListSheet(
                profiles: edgeProfiles,
                currentId: measurement?.edgeProfileId
            ) { profile in
                measurement?.edgeProfileId = profile.id
                measurement?.edgeChanged = (profile.id != measurement?.quotedEdgeProfileId)
                onSave()
            }
        }
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack {
            Button { withAnimation { isExpanded.toggle() } } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(surface.displayName)
                                .font(.subheadline.bold())
                            if measurement?.isFieldAdded == true {
                                StatusBadge(text: "Field Added", color: .purple)
                            }
                        }

                        if let material = surface.materialName {
                            Text(material)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Collapsed summary
                        if !isExpanded {
                            collapsedSummary
                        }
                    }

                    if measurement?.isMeasured == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }

                    if measurement?.hasDimensionChange == true {
                        StatusBadge(text: "Changed", color: .orange)
                    }

                    Spacer()
                }
            }
            .tint(.primary)

            if !isReadOnly, let onCamera {
                Button { onCamera() } label: {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(.trailing, 8)
            }

            Button { withAnimation { isExpanded.toggle() } } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
            }
            .tint(.primary)
        }
    }

    @ViewBuilder
    private var collapsedSummary: some View {
        HStack(spacing: 8) {
            if let l = measurement?.actualLengthIn, let w = measurement?.actualWidthIn {
                Text("\(formatInchesDisplay(l)) \u{00D7} \(formatInchesDisplay(w))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let edgeName = currentEdgeName {
                Text(edgeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !seamLocations.isEmpty {
                Text("\(seamLocations.count) seam\(seamLocations.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Quoted Dimensions

    @ViewBuilder
    private var quotedDimensions: some View {
        if let qL = measurement?.quotedLengthIn, let qW = measurement?.quotedWidthIn {
            HStack {
                Text("Quoted:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(formatInchesDisplay(qL)) \u{00D7} \(formatInchesDisplay(qW))")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if let sqft = measurement?.quotedSqft {
                    Text("(\(String(format: "%.1f", sqft)) sqft)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else if let estL = surface.estimatedLengthInches, let estW = surface.estimatedWidthInches {
            HStack {
                Text("Estimated:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(formatInchesDisplay(estL)) \u{00D7} \(formatInchesDisplay(estW))")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if let sqft = surface.estimatedSqft {
                    Text("(\(String(format: "%.1f", sqft)) sqft)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actual Dimensions

    private var actualDimensions: some View {
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
                            commitDimensions()
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
                            commitDimensions()
                        }
                    Text("\"")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let sqft = calculatedSqft {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Sqft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", sqft))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Edge Profile

    private var edgeProfileSection: some View {
        EdgeProfilePicker(
            currentName: currentEdgeName,
            quotedName: measurement?.edgeChanged == true ? surface.edgeProfileName : nil,
            isChanged: measurement?.edgeChanged == true,
            isReadOnly: isReadOnly
        ) {
            showEdgeSheet = true
        }
    }

    // MARK: - Overhang

    private var overhangSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Overhang Depth")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField("0", text: $overhangText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 80)
                    .disabled(isReadOnly)
                    .onChange(of: overhangText) {
                        overhangText = filterNumeric(overhangText)
                        let newValue = Double(overhangText)
                        guard newValue != measurement?.overhangDepthIn else { return }
                        measurement?.overhangDepthIn = newValue
                        onSave()
                    }
                Text("in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Finished Edges

    private var finishedEdgesSection: some View {
        FinishedEdgesView(
            finishedEdges: $finishedEdges,
            isReadOnly: isReadOnly
        )
        .onChange(of: finishedEdges) {
            guard finishedEdges != measurement?.finishedEdges else { return }
            measurement?.finishedEdges = finishedEdges
            onSave()
        }
    }

    // MARK: - Seams

    private var seamSection: some View {
        SeamLocationEditor(
            seamLocations: $seamLocations,
            isReadOnly: isReadOnly
        )
        .onChange(of: seamLocations) {
            let encoded = encodeSeamLocations(seamLocations)
            guard encoded != measurement?.seamLocationsJson else { return }
            measurement?.seamLocationsJson = encoded
            onSave()
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Template Notes")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Notes...", text: $notesText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .disabled(isReadOnly)
                .onChange(of: notesText) {
                    let newNotes = notesText.isEmpty ? nil : notesText
                    guard newNotes != measurement?.templateNotes else { return }
                    measurement?.templateNotes = newNotes
                    onSave()
                }
        }
    }

    // MARK: - Computed

    private var calculatedSqft: Double? {
        guard let l = Double(lengthText), let w = Double(widthText), l > 0, w > 0 else { return nil }
        return (l * w) / 144.0
    }

    private var currentEdgeName: String? {
        if let id = measurement?.edgeProfileId {
            return edgeProfiles.first { $0.id == id }?.name ?? surface.edgeProfileName
        }
        return surface.edgeProfileName
    }

    // MARK: - Actions

    private func loadFields() {
        lengthText = (measurement?.actualLengthIn ?? surface.actualLengthInches).map { formatValue($0) } ?? ""
        widthText = (measurement?.actualWidthIn ?? surface.actualWidthInches).map { formatValue($0) } ?? ""
        overhangText = measurement?.overhangDepthIn.map { formatValue($0) } ?? ""
        seamLocations = parseSeamLocations(measurement?.seamLocationsJson)
        finishedEdges = measurement?.finishedEdges ?? ""
        notesText = measurement?.templateNotes ?? surface.templateNotes ?? ""
    }

    private func commitDimensions() {
        let newLength = Double(lengthText)
        let newWidth = Double(widthText)
        guard newLength != measurement?.actualLengthIn || newWidth != measurement?.actualWidthIn else { return }
        measurement?.actualLengthIn = newLength
        measurement?.actualWidthIn = newWidth
        onSave()
    }
}
