import SwiftUI

struct CutoutSection: View {
    let cutouts: [CachedCutout]
    let isReadOnly: Bool
    let onAdd: (CutoutFormData) -> Void
    let onRemove: (CachedCutout) -> Void
    /// Opens the check of a sink from the sink & faucet sheet.
    var onCheck: ((CachedCutout) -> Void)? = nil

    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Cutouts")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if !cutouts.isEmpty {
                    Text("(\(cutouts.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !isReadOnly {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.sfAccentStrong)
                    }
                }
            }

            if cutouts.isEmpty {
                Text("No cutouts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(cutouts, id: \.cutoutId) { cutout in
                if cutout.isQuotedSink {
                    QuotedSinkRow(cutout: cutout) { onCheck?(cutout) }
                } else {
                    CutoutRow(cutout: cutout, isReadOnly: isReadOnly) {
                        onRemove(cutout)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCutoutSheet { data in
                onAdd(data)
            }
        }
    }
}

/// A sink from the sink & faucet sheet: what the sheet says, and whether the tech has checked it
/// (Matches the sheet / CHANGED). Tapping opens the check; it can't be removed.
private struct QuotedSinkRow: View {
    let cutout: CachedCutout
    let onCheck: () -> Void

    var body: some View {
        let q = cutout.quoted
        let changes = q.map { cutout.sinkCheck.changeLines(from: $0) } ?? []
        Button(action: onCheck) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Sink").font(.subheadline.bold())
                        StatusBadge(text: "Sink sheet v\(cutout.sinkSheetVersion ?? 1)", color: .sfAccentStrong)
                        if cutout.checkedAt == nil {
                            StatusBadge(text: "Check on site", color: .sfWarning)
                        } else if !changes.isEmpty {
                            StatusBadge(text: "CHANGED", color: .sfDanger)
                        } else {
                            StatusBadge(text: "Matches sheet", color: .sfSuccess)
                        }
                    }
                    if let q {
                        Text("\(q.sinkTitle) · \(Inches.size(q.sinkCutoutWidth, q.sinkCutoutDepth))")
                            .font(.caption).foregroundStyle(.secondary)
                        if let faucet = q.faucetTitle {
                            Text("Faucet: \(faucet)").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Holes: \(q.holesInWords(cutout.holes))").font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(changes, id: \.self) { line in
                        Text(line).font(.caption2).foregroundStyle(.sfDanger)
                    }
                    if cutout.bringToShop {
                        Text("Sink not on site: bring to shop").font(.caption2).foregroundStyle(.sfWarning)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .accessibilityIdentifier("quotedSinkRow")
    }
}

private struct CutoutRow: View {
    let cutout: CachedCutout
    let isReadOnly: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(cutout.displayType)
                        .font(.subheadline.bold())
                    if cutout.source == "field" {
                        StatusBadge(text: "Field", color: .sfInfo)
                    }
                    if cutout.count > 1 {
                        Text("\u{00D7}\(cutout.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !cutout.displayDetail.isEmpty {
                    Text(cutout.displayDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if cutout.cutoutType == "sink" {
                    HStack(spacing: 8) {
                        if let holes = cutout.faucetHoles, holes > 0 {
                            Text("\(holes) faucet hole\(holes == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if cutout.bringToShop {
                            Text("Bring to shop")
                                .font(.caption2)
                                .foregroundStyle(.sfWarning)
                        }
                    }
                }
                if cutout.cutoutType == "cooktop", let onsite = cutout.cooktopOnsite {
                    Text(onsite ? "On-site" : "Not on-site")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let note = cutout.locationNote, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            Spacer()

            if !isReadOnly {
                Button(role: .destructive) { onRemove() } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
