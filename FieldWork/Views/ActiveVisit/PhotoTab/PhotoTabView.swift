import SwiftUI
import PhotosUI
import SwiftData

struct PhotoTabView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showCamera = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedSurfaceId: UUID?
    @State private var surfaceFilter: UUID?  // nil = "All"
    @State private var selectedPhotoForDetail: CachedPhoto?

    private var filteredPhotos: [CachedPhoto] {
        guard let filter = surfaceFilter else { return viewModel.photos }
        return viewModel.photos.filter { $0.surfaceId == filter }
    }

    private var unsyncedCount: Int {
        viewModel.photos.filter { !$0.isSynced }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Surface filter bar
            if !viewModel.booking.surfaces.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "All", count: viewModel.photos.count, isSelected: surfaceFilter == nil) {
                            surfaceFilter = nil
                        }

                        ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                            let count = viewModel.photos.filter { $0.surfaceId == surface.surfaceId }.count
                            FilterChip(
                                label: surface.displayName,
                                count: count,
                                isSelected: surfaceFilter == surface.surfaceId
                            ) {
                                surfaceFilter = surface.surfaceId
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(.bar)
            }

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

            // Photo grid
            ScrollView {
                if filteredPhotos.isEmpty {
                    ContentUnavailableView(
                        surfaceFilter != nil ? "No Photos for This Surface" : "No Photos",
                        systemImage: "camera",
                        description: Text("Take photos of the job site and surfaces.")
                    )
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 3),
                        GridItem(.flexible(), spacing: 3),
                        GridItem(.flexible(), spacing: 3)
                    ], spacing: 3) {
                        ForEach(filteredPhotos, id: \.localId) { photo in
                            PhotoThumbnail(photo: photo)
                                .onTapGesture {
                                    selectedPhotoForDetail = photo
                                }
                        }
                    }
                    .padding(3)
                }
            }

            // Capture controls
            if viewModel.booking.visitStatus != "completed" {
                VStack(spacing: 8) {
                    // Surface picker
                    HStack {
                        Text("Tag:")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)

                        Picker("Surface", selection: $selectedSurfaceId) {
                            Text("General").tag(nil as UUID?)
                            ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                                Text(surface.displayName).tag(surface.surfaceId as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)

                        Spacer()
                    }
                    .padding(.horizontal)

                    HStack(spacing: 16) {
                        // Camera button
                        Button {
                            showCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)

                        // Photo library (multi-select)
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
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                viewModel.capturePhoto(
                    image: image,
                    surfaceId: selectedSurfaceId,
                    context: modelContext
                )
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel.capturePhoto(
                            image: image,
                            surfaceId: selectedSurfaceId,
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
                        viewModel.showMarkup = true
                    }
                }
            )
        }
    }

    private func deletePhoto(_ photo: CachedPhoto) {
        // Remove local files
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
            .background(isSelected ? .blue : .secondary.opacity(0.12))
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
            if photo.hasAnnotations {
                Image(systemName: "pencil.tip.crop.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.blue)
                    .clipShape(Circle())
                    .padding(4)
            }
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

    private func loadImage() -> UIImage? {
        // Prefer thumbnail for grid performance
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
                    // Surface picker
                    HStack {
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

                        // Timestamp
                        Text(photo.capturedAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
