import SwiftUI
import PhotosUI
import SwiftData

struct PhotoTabView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showCamera = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedSurfaceId: UUID?
    @State private var photoFilter: PhotoFilter = .all
    @State private var selectedPhotoForDetail: CachedPhoto?
    @State private var captureCategory: String = "general"

    private enum PhotoFilter: Equatable, Hashable {
        case all, site, damage, hazard, surface(UUID)
    }

    // MARK: - Filtered / grouped photos

    private var filteredPhotos: [CachedPhoto] {
        switch photoFilter {
        case .all:
            return viewModel.photos
        case .site:
            return viewModel.photos.filter { $0.category == "site" || $0.siteConditionKey != nil }
        case .damage:
            return viewModel.photos.filter { $0.category == "damage" }
        case .hazard:
            return viewModel.photos.filter { $0.category == "hazard" }
        case .surface(let id):
            return viewModel.photos.filter { $0.surfaceId == id }
        }
    }

    private func photoCount(for filter: PhotoFilter) -> Int {
        switch filter {
        case .all: return viewModel.photos.count
        case .site: return viewModel.photos.filter { $0.category == "site" || $0.siteConditionKey != nil }.count
        case .damage: return viewModel.photos.filter { $0.category == "damage" }.count
        case .hazard: return viewModel.photos.filter { $0.category == "hazard" }.count
        case .surface(let id): return viewModel.photos.filter { $0.surfaceId == id }.count
        }
    }

    private var unsyncedCount: Int {
        viewModel.photos.filter { !$0.isSynced }.count
    }

    /// Group photos by category for the "all" view
    private var groupedPhotos: [(key: String, title: String, icon: String, tint: Color, photos: [CachedPhoto])] {
        let categories: [(key: String, title: String, icon: String, tint: Color)] = [
            ("damage", "Damage", "exclamationmark.triangle.fill", .red),
            ("hazard", "Hazard", "bolt.trianglebadge.exclamationmark.fill", .orange),
            ("site", "Site Conditions", "mappin.circle.fill", .orange),
            ("surface", "Surface", "square.stack.3d.up", .blue),
            ("general", "General", "photo", .secondary),
        ]

        return categories.compactMap { cat in
            let photos: [CachedPhoto]
            switch cat.key {
            case "site":
                photos = viewModel.photos.filter { $0.category == "site" || ($0.siteConditionKey != nil && $0.category == "general") }
            case "surface":
                photos = viewModel.photos.filter { $0.surfaceId != nil && $0.category != "site" && $0.category != "damage" && $0.category != "hazard" && $0.siteConditionKey == nil }
            case "general":
                photos = viewModel.photos.filter { $0.category == "general" && $0.surfaceId == nil && $0.siteConditionKey == nil }
            default:
                photos = viewModel.photos.filter { $0.category == cat.key }
            }
            guard !photos.isEmpty else { return nil }
            return (key: cat.key, title: cat.title, icon: cat.icon, tint: cat.tint, photos: photos)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All", count: photoCount(for: .all), isSelected: photoFilter == .all) {
                        photoFilter = .all
                    }

                    FilterChip(
                        label: "Site",
                        count: photoCount(for: .site),
                        isSelected: photoFilter == .site,
                        tint: .orange
                    ) {
                        photoFilter = .site
                    }

                    FilterChip(
                        label: "Damage",
                        count: photoCount(for: .damage),
                        isSelected: photoFilter == .damage,
                        tint: .red
                    ) {
                        photoFilter = .damage
                    }

                    FilterChip(
                        label: "Hazard",
                        count: photoCount(for: .hazard),
                        isSelected: photoFilter == .hazard,
                        tint: .yellow
                    ) {
                        photoFilter = .hazard
                    }

                    ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                        let count = photoCount(for: .surface(surface.surfaceId))
                        FilterChip(
                            label: surface.displayName,
                            count: count,
                            isSelected: photoFilter == .surface(surface.surfaceId)
                        ) {
                            photoFilter = .surface(surface.surfaceId)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.bar)

            // Sync status banner
            if unsyncedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                    Text("\(unsyncedCount) photo\(unsyncedCount == 1 ? "" : "s") waiting to upload")
                        .font(.caption)
                }
                .foregroundStyle(.orange)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(.orange.opacity(0.1))
            }

            // Photo content
            ScrollView {
                if filteredPhotos.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "camera",
                        description: Text(emptyDescription)
                    )
                    .padding(.top, 60)
                } else if photoFilter == .all && groupedPhotos.count > 1 {
                    // Grouped view when showing "All"
                    LazyVStack(spacing: 0) {
                        ForEach(groupedPhotos, id: \.key) { group in
                            PhotoGroupHeader(
                                title: group.title,
                                icon: group.icon,
                                count: group.photos.count,
                                tint: group.tint,
                                onAdd: viewModel.booking.visitStatus != "completed" ? {
                                    captureCategory = group.key == "surface" ? "general" : group.key
                                    showCamera = true
                                } : nil
                            )

                            photoGrid(for: group.photos)
                        }
                    }
                } else {
                    // Flat grid for filtered views
                    photoGrid(for: filteredPhotos)
                        .padding(.top, 4)
                }
            }

            // Capture controls
            if viewModel.booking.visitStatus != "completed" {
                captureBar
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                let category = determineCaptureCategory()
                viewModel.capturePhoto(
                    image: image,
                    surfaceId: selectedSurfaceId,
                    category: category,
                    context: modelContext
                )
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                let category = determineCaptureCategory()
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel.capturePhoto(
                            image: image,
                            surfaceId: selectedSurfaceId,
                            category: category,
                            context: modelContext
                        )
                    }
                }
                selectedPhotos = []
            }
        }
        .sheet(item: $selectedPhotoForDetail) { photo in
            PhotoDetailView(
                photo: photo,
                surfaces: viewModel.booking.surfaces,
                onDelete: { deletePhoto(photo) },
                onMarkup: {
                    if let image = UIImage(contentsOfFile: photo.localFilePath) {
                        selectedPhotoForDetail = nil
                        viewModel.pendingImage = image
                        viewModel.pendingSurfaceId = photo.surfaceId
                        viewModel.pendingCategory = photo.category
                        viewModel.showMarkup = true
                    }
                }
            )
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func photoGrid(for photos: [CachedPhoto]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 3),
            GridItem(.flexible(), spacing: 3),
            GridItem(.flexible(), spacing: 3)
        ], spacing: 3) {
            ForEach(photos, id: \.localId) { photo in
                PhotoThumbnail(photo: photo)
                    .onTapGesture {
                        selectedPhotoForDetail = photo
                    }
            }
        }
        .padding(.horizontal, 3)
    }

    private var captureBar: some View {
        VStack(spacing: 8) {
            // Category + surface picker row
            HStack {
                // Category picker
                Picker("Category", selection: $captureCategory) {
                    Text("General").tag("general")
                    Text("Damage").tag("damage")
                    Text("Hazard").tag("hazard")
                }
                .pickerStyle(.menu)
                .tint(.primary)

                Divider()
                    .frame(height: 20)

                // Surface picker
                HStack(spacing: 4) {
                    Text("Tag:")
                        .font(.caption.bold())
                    Picker("Surface", selection: $selectedSurfaceId) {
                        Text("None").tag(nil as UUID?)
                        ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                            Text(surface.displayName).tag(surface.surfaceId as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }

                Spacer()
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)

                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Helpers

    private func determineCaptureCategory() -> String {
        // If a filter is active, use it as the category hint
        switch photoFilter {
        case .damage: return "damage"
        case .hazard: return "hazard"
        case .site: return "site"
        case .surface: return selectedSurfaceId != nil ? "general" : "general"
        case .all: return captureCategory
        }
    }

    private var emptyTitle: String {
        switch photoFilter {
        case .all: "No Photos"
        case .site: "No Site Photos"
        case .damage: "No Damage Photos"
        case .hazard: "No Hazard Photos"
        case .surface: "No Photos for This Surface"
        }
    }

    private var emptyDescription: String {
        switch photoFilter {
        case .site: "Use the Site tab to capture site condition photos."
        case .damage: "Capture photos of any pre-existing damage."
        case .hazard: "Capture photos of any safety hazards."
        default: "Take photos of the job site and surfaces."
        }
    }

    private func deletePhoto(_ photo: CachedPhoto) {
        try? FileManager.default.removeItem(atPath: photo.localFilePath)
        if let thumbPath = photo.thumbnailPath {
            try? FileManager.default.removeItem(atPath: thumbPath)
        }
        viewModel.photos.removeAll { $0.localId == photo.localId }
        modelContext.delete(photo)
        try? modelContext.save()
        selectedPhotoForDetail = nil
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let count: Int
    let isSelected: Bool
    var tint: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .lineLimit(1)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? .white.opacity(0.3) : .secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? tint : .secondary.opacity(0.12))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Photo Thumbnail

struct PhotoThumbnail: View {
    let photo: CachedPhoto

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .aspectRatio(1, contentMode: .fill)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 2) {
                if photo.category == "damage" {
                    categoryBadge(icon: "exclamationmark.triangle.fill", color: .red)
                } else if photo.category == "hazard" {
                    categoryBadge(icon: "bolt.trianglebadge.exclamationmark.fill", color: .orange)
                } else if photo.siteConditionKey != nil || photo.category == "site" {
                    categoryBadge(icon: "mappin.circle.fill", color: .orange)
                }
                if photo.hasAnnotations {
                    categoryBadge(icon: "pencil.tip.crop.circle.fill", color: .blue)
                }
            }
            .padding(4)
        }
        .overlay(alignment: .bottomTrailing) {
            if !photo.isSynced {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private func categoryBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(4)
            .background(color)
            .clipShape(Circle())
    }

    private func loadImage() -> UIImage? {
        if let thumbPath = photo.thumbnailPath {
            if let thumb = UIImage(contentsOfFile: thumbPath) {
                return thumb
            }
        }
        return UIImage(contentsOfFile: photo.localFilePath)
    }
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    let photo: CachedPhoto
    let surfaces: [CachedSurface]
    let onDelete: () -> Void
    let onMarkup: () -> Void
    let onSurfaceChanged: ((UUID?) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false
    @State private var selectedSurfaceId: UUID?

    init(
        photo: CachedPhoto,
        surfaces: [CachedSurface],
        onDelete: @escaping () -> Void,
        onMarkup: @escaping () -> Void,
        onSurfaceChanged: ((UUID?) -> Void)? = nil
    ) {
        self.photo = photo
        self.surfaces = surfaces
        self.onDelete = onDelete
        self.onMarkup = onMarkup
        self.onSurfaceChanged = onSurfaceChanged
        _selectedSurfaceId = State(initialValue: photo.surfaceId)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Full-size photo
                if let image = UIImage(contentsOfFile: photo.localFilePath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black)
                } else {
                    ContentUnavailableView("Photo Not Found", systemImage: "photo")
                }

                // Info bar
                VStack(spacing: 8) {
                    // Category + Surface row
                    HStack {
                        // Category badge
                        categoryLabel

                        Image(systemName: "tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Surface", selection: $selectedSurfaceId) {
                            Text("General").tag(nil as UUID?)
                            ForEach(surfaces, id: \.surfaceId) { surface in
                                Text(surface.displayName).tag(surface.surfaceId as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)
                        .onChange(of: selectedSurfaceId) { _, newValue in
                            photo.surfaceId = newValue
                            try? modelContext.save()
                            onSurfaceChanged?(newValue)
                        }

                        Spacer()

                        Text(photo.capturedAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Site tags
                    if let tagKeys = photo.siteConditionKey, !tagKeys.isEmpty {
                        let tags = tagKeys.split(separator: ",").compactMap { SiteTags.label(for: String($0)) }
                        if !tags.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.orange.opacity(0.15))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let caption = photo.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        if photo.hasAnnotations {
                            Label("Annotated", systemImage: "pencil.tip.crop.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }

                        if !photo.isSynced {
                            Label("Pending upload", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        } else {
                            Label("Uploaded", systemImage: "checkmark.circle")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        onMarkup()
                    } label: {
                        Image(systemName: "pencil.tip.crop.circle")
                    }

                    if !photo.isSynced {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog("Delete Photo?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            } message: {
                Text("This photo hasn't been uploaded yet. Deleting it cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private var categoryLabel: some View {
        switch photo.category {
        case "damage":
            Label("Damage", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2.bold())
                .foregroundStyle(.red)
        case "hazard":
            Label("Hazard", systemImage: "bolt.trianglebadge.exclamationmark.fill")
                .font(.caption2.bold())
                .foregroundStyle(.orange)
        case "site":
            Label("Site", systemImage: "mappin.circle.fill")
                .font(.caption2.bold())
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
