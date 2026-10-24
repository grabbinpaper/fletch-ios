import SwiftUI
import SwiftData
import PhotosUI

/// Checking a sink from the sink & faucet sheet against what's really on site. The sheet's answers
/// are filled in; the tech confirms or changes them. It can't be a tick: saving needs the sink's box
/// label (or model number) photographed and its cutout measured — or the sink marked not on site —
/// and a photo of the faucet or its spec sheet. Whatever differs from the sheet shows as CHANGED here
/// and in the office, where it's worked out again from the same answers.
struct QuotedSinkCheckView: View {
    let cutout: CachedCutout
    @Bindable var viewModel: ActiveVisitViewModel
    let isReadOnly: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var check: SinkCheck
    @State private var widthText: String
    @State private var depthText: String
    @State private var note: String
    @State private var placing = "faucet"

    init(cutout: CachedCutout, viewModel: ActiveVisitViewModel, isReadOnly: Bool) {
        self.cutout = cutout
        self.viewModel = viewModel
        self.isReadOnly = isReadOnly
        _check = State(initialValue: cutout.sinkCheck)
        // Never filled in from the sheet: the tech has to measure it.
        _widthText = State(initialValue: cutout.measuredCutoutWidth.map { Inches.format($0).replacingOccurrences(of: "\"", with: "") } ?? "")
        _depthText = State(initialValue: cutout.measuredCutoutDepth.map { Inches.format($0).replacingOccurrences(of: "\"", with: "") } ?? "")
        _note = State(initialValue: cutout.locationNote ?? "")
    }

    var body: some View {
        NavigationStack {
            if let q = cutout.quoted {
                form(q)
            } else {
                Text("This sink's sheet couldn't be read. Pull down on the schedule to refresh.")
                    .padding()
            }
        }
    }

    private func form(_ q: QuotedSinkSheet) -> some View {
        let hasSinkPhoto = viewModel.hasEvidencePhoto(cutout, category: "sink_label")
        let hasFaucetPhoto = viewModel.hasEvidencePhoto(cutout, category: "faucet")
        let missing = check.missingEvidence(quoted: q, hasSinkPhoto: hasSinkPhoto, hasFaucetPhoto: hasFaucetPhoto)
        let changes = check.changeLines(from: q)

        return Form {
            sheetSection(q)
            sinkSection(q, hasPhoto: hasSinkPhoto)
            if q.hasFaucet { faucetSection(q, hasPhoto: hasFaucetPhoto) }
            holesSection(q)

            Section("Note for the office") {
                TextField("e.g. customer wants the faucet moved left", text: $note, axis: .vertical)
                    .disabled(isReadOnly)
            }

            Section {
                if changes.isEmpty {
                    Label("Matches the sheet", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                } else {
                    ForEach(changes, id: \.self) { line in
                        Label(line, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.subheadline)
                    }
                    Text("The office sees this as CHANGED, old → new, to sort out with the customer before anything is cut.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text(changes.isEmpty ? "Result" : "CHANGED from the sheet")
            }

            if !isReadOnly && !missing.isEmpty {
                Section("Still needed") {
                    ForEach(missing, id: \.self) { Label($0, systemImage: "circle").font(.subheadline) }
                }
            }
        }
        .navigationTitle("Check the sink")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(isReadOnly ? "Close" : "Cancel") { dismiss() }
            }
            if !isReadOnly {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveSinkCheck(cutout, check: check, note: note.nonEmpty, context: modelContext)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!missing.isEmpty)
                    .accessibilityIdentifier("saveSinkCheck")
                }
            }
        }
    }

    // MARK: - What the sheet says

    private func sheetSection(_ q: QuotedSinkSheet) -> some View {
        Section("Sink & faucet sheet v\(q.version ?? cutout.sinkSheetVersion ?? 1) (signed with the quote)") {
            LabeledContent("Sink", value: q.sinkTitle)
            LabeledContent("Cutout", value: Inches.size(q.sinkCutoutWidth, q.sinkCutoutDepth))
            if q.sinkMount != nil { LabeledContent("Mount", value: SinkCheck.mountLabel(q.sinkMount)) }
            if let faucet = q.faucetTitle {
                LabeledContent("Faucet", value: faucet)
                if let n = q.faucetHoleCount {
                    LabeledContent("Faucet holes", value: n > 1 && q.faucetHoleSpacing != nil
                                   ? "\(n), \(Inches.format(q.faucetHoleSpacing!)) apart" : "\(n)")
                }
            }
            ForEach(q.extras ?? [], id: \.id) { e in
                LabeledContent(e.label, value: [e.makeModel?.nonEmpty, e.holeSize.map { "\(Inches.format($0)) hole" }].compactMap { $0 }.joined(separator: " · "))
            }
            LabeledContent("Holes", value: q.holesInWords(q.holes ?? []))
            if let n = q.note?.nonEmpty { Text(n).font(.caption).foregroundStyle(.secondary) }
        }
    }

    // MARK: - The sink

    private func sinkSection(_ q: QuotedSinkSheet, hasPhoto: Bool) -> some View {
        Section {
            YesNo(title: "Is the sink here?", yes: "Yes, it's here", no: "Not here",
                  value: $check.sinkOnSite, disabled: isReadOnly)
            if check.sinkOnSite == false {
                Text("Marked **bring to shop**: the shop checks the sink when it comes in. Change the make or model only if the customer says it's a different sink.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if check.sinkOnSite == true {
                EvidencePhotoButton(title: "Photo of the box label or model number", done: hasPhoto, disabled: isReadOnly) { image in
                    viewModel.saveEvidencePhoto(image, cutout: cutout, category: "sink_label", context: modelContext)
                }
            }
            TextField("Make", text: binding(\.make)).disabled(isReadOnly)
            TextField("Model", text: binding(\.model)).disabled(isReadOnly)
            Picker("Mount", selection: $check.mount) {
                Text("Not set").tag(String?.none)
                ForEach(SinkCheck.mounts, id: \.0) { Text($0.1).tag(Optional($0.0)) }
            }
            .disabled(isReadOnly)
            if check.sinkOnSite == true {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Measure the sink's cutout").font(.subheadline)
                    HStack {
                        TextField("Side to side", text: $widthText)
                            .keyboardType(.numbersAndPunctuation)
                            .accessibilityIdentifier("cutoutWidth")
                        Text("×")
                        TextField("Front to back", text: $depthText)
                            .keyboardType(.numbersAndPunctuation)
                            .accessibilityIdentifier("cutoutDepth")
                    }
                    .textFieldStyle(.roundedBorder)
                    .disabled(isReadOnly)
                    .onChange(of: widthText) { check.measuredWidth = Inches.parse(widthText) }
                    .onChange(of: depthText) { check.measuredDepth = Inches.parse(depthText) }
                    cutoutComparison(q)
                }
            }
        } header: {
            Text("Sink")
        }
    }

    @ViewBuilder
    private func cutoutComparison(_ q: QuotedSinkSheet) -> some View {
        if let w = check.measuredWidth, let d = check.measuredDepth {
            if let qw = q.sinkCutoutWidth, let qd = q.sinkCutoutDepth {
                let ok = abs(w - qw) <= q.tolerance && abs(d - qd) <= q.tolerance
                Label(ok ? "Matches the sheet (\(Inches.size(qw, qd)), within \(Inches.format(q.tolerance)))"
                         : "Different from the sheet: \(Inches.size(qw, qd))",
                      systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(ok ? .green : .red)
            }
        } else if !widthText.isEmpty || !depthText.isEmpty {
            Text("Type inches like 29 1/2 or 29.5").font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - The faucet

    private func faucetSection(_ q: QuotedSinkSheet, hasPhoto: Bool) -> some View {
        Section("Faucet") {
            YesNo(title: "Is the faucet here?", yes: "Yes, it's here", no: "Only its spec sheet",
                  value: $check.faucetOnSite, disabled: isReadOnly)
            EvidencePhotoButton(title: check.faucetOnSite == false ? "Photo of the faucet's spec sheet" : "Photo of the faucet (or its spec sheet)",
                                done: hasPhoto, disabled: isReadOnly) { image in
                viewModel.saveEvidencePhoto(image, cutout: cutout, category: "faucet", context: modelContext)
            }
            TextField("Make", text: binding(\.faucetMake)).disabled(isReadOnly)
            TextField("Model", text: binding(\.faucetModel)).disabled(isReadOnly)
            Stepper("Faucet holes: \(check.faucetHoles ?? 0)", value: Binding(
                get: { check.faucetHoles ?? 0 },
                set: { n in
                    check.faucetHoles = n
                    // Fewer faucet holes: drop the extra ones from the right.
                    let faucet = check.holes.filter { $0.use == "faucet" }.sorted { $0.x < $1.x }
                    if faucet.count > n {
                        let drop = Set(faucet.suffix(faucet.count - n).map(\.x))
                        check.holes.removeAll { $0.use == "faucet" && drop.contains($0.x) }
                    }
                }), in: 0...6)
            .disabled(isReadOnly)
        }
    }

    // MARK: - Where the holes go

    private func holesSection(_ q: QuotedSinkSheet) -> some View {
        let uses = q.holeUses(faucetHoles: check.faucetHoles)
        return Section {
            if q.positions.isEmpty {
                Text("The sheet has no hole positions for this sink.").font(.caption).foregroundStyle(.secondary)
            } else {
                if uses.count > 1 && !isReadOnly {
                    Picker("Placing", selection: $placing) {
                        ForEach(uses, id: \.use) { Text($0.label).tag($0.use) }
                    }
                    .pickerStyle(.segmented)
                }
                HoleLayout(quoted: q, holes: $check.holes, uses: uses, placing: uses.contains { $0.use == placing } ? placing : uses.first?.use,
                           disabled: isReadOnly)
                    .frame(height: 150)
                Text(q.holesInWords(check.holes)).font(.caption)
                if !isReadOnly {
                    Text("Tap a position to add or remove a hole. Dashed rings are where the sheet has them.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Where the holes go")
        }
    }

    private func binding(_ key: WritableKeyPath<SinkCheck, String?>) -> Binding<String> {
        Binding(get: { check[keyPath: key] ?? "" }, set: { check[keyPath: key] = $0.nonEmpty })
    }
}

/// Two buttons for a yes/no that starts unanswered (so it can't be left on a default).
private struct YesNo: View {
    let title: String
    let yes: String
    let no: String
    @Binding var value: Bool?
    let disabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            HStack {
                choice(yes, true)
                choice(no, false)
            }
        }
        .disabled(disabled)
    }

    private func choice(_ label: String, _ v: Bool) -> some View {
        Button { value = v } label: {
            Text(label).font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(value == v ? .blue : .gray)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(value == v ? Color.blue : .clear, lineWidth: 2))
    }
}

/// Takes an evidence photo with the camera. Only the iOS Simulator (no camera) picks from the
/// photo library instead, so on a phone the photo is always taken on site.
private struct EvidencePhotoButton: View {
    let title: String
    let done: Bool
    let disabled: Bool
    let onImage: (UIImage) -> Void

    @State private var showCamera = false
    @State private var pick: PhotosPickerItem?

    var body: some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "camera.fill")
                .foregroundStyle(done ? .green : .blue)
            #if targetEnvironment(simulator)
            PhotosPicker(selection: $pick, matching: .images) { Text(done ? "\(title) ✓ (add another)" : title) }
                .disabled(disabled)
                .onChange(of: pick) {
                    guard let item = pick else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                            await MainActor.run { onImage(image) }
                        }
                        await MainActor.run { pick = nil }
                    }
                }
            #else
            Button(done ? "\(title) ✓ (retake)" : title) { showCamera = true }
                .disabled(disabled)
            #endif
        }
        .sheet(isPresented: $showCamera) {
            CameraView { onImage($0) }
        }
    }
}

/// The sink cutout from above with its possible hole positions behind it (to scale). Filled circles
/// are holes, coloured by what they're for; dashed rings are where the sheet put them.
private struct HoleLayout: View {
    let quoted: QuotedSinkSheet
    @Binding var holes: [SheetHole]
    let uses: [(use: String, label: String, max: Int)]
    let placing: String?
    let disabled: Bool

    private static let colors: [Color] = [.blue, .green, .orange, .purple, .teal, .pink]
    private func color(_ use: String) -> Color {
        Self.colors[max(0, uses.firstIndex { $0.use == use } ?? 0) % Self.colors.count]
    }

    var body: some View {
        GeometryReader { geo in
            let positions = quoted.positions
            let span = max((positions.map(abs).max() ?? 0) * 2 + 4, quoted.sinkCutoutWidth ?? 0)
            let scale = geo.size.width / max(span, 1)
            let mid = geo.size.width / 2
            let holeY: CGFloat = 22
            let sinkW = (quoted.sinkCutoutWidth ?? span * 0.8) * scale
            let sinkH = min(geo.size.height - holeY - 40, (quoted.sinkCutoutDepth ?? 18) * scale)
            let quotedXs = Set((quoted.holes ?? []).map(\.x))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary, lineWidth: 1.5)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
                    .frame(width: sinkW, height: max(sinkH, 30))
                    .position(x: mid, y: holeY + 34 + max(sinkH, 30) / 2)
                ForEach(positions, id: \.self) { x in
                    let hole = holes.first { $0.x == x }
                    let px = mid + x * scale
                    ZStack {
                        if quotedXs.contains(x) {
                            Circle().stroke(style: StrokeStyle(lineWidth: 1, dash: [3])).foregroundStyle(.secondary)
                                .frame(width: 30, height: 30)
                        }
                        Circle()
                            .fill(hole.map { color($0.use) } ?? Color.clear)
                            .overlay(Circle().stroke(hole.map { color($0.use) } ?? .gray, lineWidth: 1.5))
                            .frame(width: 22, height: 22)
                    }
                    .position(x: px, y: holeY)
                    Text(x == 0 ? "C" : Inches.format(abs(x)) + (x < 0 ? "L" : "R"))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .position(x: px, y: holeY + 22)
                }
            }
            .contentShape(Rectangle())
            // One tap handler for the whole drawing: the nearest position to the tap, if close enough.
            .gesture(SpatialTapGesture().onEnded { tap in
                guard tap.location.y < holeY + 40,
                      let x = positions.min(by: { abs(mid + $0 * scale - tap.location.x) < abs(mid + $1 * scale - tap.location.x) }),
                      abs(mid + x * scale - tap.location.x) < 24 else { return }
                toggle(x)
            })
        }
        .disabled(disabled)
    }

    private func toggle(_ x: Double) {
        guard let placing, let max = uses.first(where: { $0.use == placing })?.max else { return }
        if let i = holes.firstIndex(where: { $0.x == x }) {
            let wasSame = holes[i].use == placing
            holes.remove(at: i)
            if wasSame { return }
        }
        if holes.filter({ $0.use == placing }).count < max {
            holes.append(SheetHole(x: x, use: placing))
        }
    }
}
