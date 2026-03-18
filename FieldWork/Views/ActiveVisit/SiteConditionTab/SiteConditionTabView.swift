import SwiftUI
import SwiftData

struct SiteConditionTabView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showCamera = false

    private var isReadOnly: Bool {
        viewModel.booking.visitStatus == "completed"
    }

    private var sitePhotos: [CachedPhoto] {
        viewModel.photos.filter { $0.siteConditionKey != nil }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    // Photo grid
                    if sitePhotos.isEmpty {
                        ContentUnavailableView(
                            "No Site Photos",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("Take photos to document site conditions. You can tag each photo and add notes.")
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(sitePhotos, id: \.localId) { photo in
                                SitePhotoCell(photo: photo)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                // Extra bottom padding so content isn't hidden behind the button
                .padding(.bottom, 70)
            }

            // Floating camera button at bottom for easy thumb access
            if !isReadOnly {
                Button {
                    viewModel.isSiteCapture = true
                    showCamera = true
                } label: {
                    Label("Take Site Photo", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
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

// MARK: - Photo Cell

private struct SitePhotoCell: View {
    let photo: CachedPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Thumbnail
            if let thumbPath = photo.thumbnailPath,
               let uiImage = UIImage(contentsOfFile: thumbPath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .cornerRadius(8)
            } else if let uiImage = UIImage(contentsOfFile: photo.localFilePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            // Tags
            if let keys = photo.siteConditionKey {
                let tagKeys = keys.split(separator: ",").map(String.init)
                FlowLayout(spacing: 2) {
                    ForEach(tagKeys, id: \.self) { key in
                        Text(SiteTags.label(for: key) ?? key)
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }

            // Note
            if let caption = photo.caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Site Tag Picker Sheet

struct SiteTagPickerSheet: View {
    @Binding var selectedTags: Set<String>
    @Binding var note: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(SiteTags.sections, id: \.0) { section, tags in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: 6) {
                                ForEach(tags) { tag in
                                    TagChip(
                                        label: tag.label,
                                        isSelected: selectedTags.contains(tag.id),
                                        onTap: {
                                            if selectedTags.contains(tag.id) {
                                                selectedTags.remove(tag.id)
                                            } else {
                                                selectedTags.insert(tag.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }

                    // Note field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note (optional)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        TextField("Add a note...", text: $note, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }
                }
                .padding()
            }
            .navigationTitle("Tag Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct TagChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
