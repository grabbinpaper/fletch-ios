import SwiftUI

struct CutoutSection: View {
    let cutouts: [CachedCutout]
    let isReadOnly: Bool
    let onAdd: (CutoutFormData) -> Void
    let onRemove: (CachedCutout) -> Void

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
                            .foregroundStyle(.blue)
                    }
                }
            }

            if cutouts.isEmpty {
                Text("No cutouts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(cutouts, id: \.cutoutId) { cutout in
                CutoutRow(cutout: cutout, isReadOnly: isReadOnly) {
                    onRemove(cutout)
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
                        StatusBadge(text: "Field", color: .purple)
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
                                .foregroundStyle(.orange)
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
