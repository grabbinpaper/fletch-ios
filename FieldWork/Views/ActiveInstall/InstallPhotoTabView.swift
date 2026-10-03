import SwiftUI
import PhotosUI
import SwiftData

struct InstallPhotoTabView: View {
    @Bindable var viewModel: ActiveInstallViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showCamera = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedSurfaceId: UUID?
    @State private var photoFilter: PhotoFilter = .all
    @State private var selectedPhotoForDetail: CachedPhoto?

    private enum PhotoFilter: Equatable, Hashable {
        case all, site, surface(UUID)
    }

    private var sitePhotos: [CachedPhoto] {
        viewModel.photos.filter { $0.surfaceId == nil }
    }

    private var filteredPhotos: [CachedPhoto] {
        switch photoFilter {
        case .all: return viewModel.photos
        case .site: return sitePhotos
        case .surface(let id): return viewModel.photos.filter { $0.surfaceId == id }
        }
    }

    private func photoCount(for filter: PhotoFilter) -> Int {
        switch filter {
        case .all: return viewModel.photos.count
        case .site: return sitePhotos.count
        case .surface(let id): return viewModel.photos.filter { $0.surfaceId == id }.count
        }
    }

    private var unsyncedCount: Int {
        viewModel.photos.filter { !$0.isSynced }.count
    }

    private var groupedPhotos: [(key: String, title: String, icon: String, tint: Color, photos: [CachedPhoto])] {
        var groups: [(key: String, title: String, icon: String, tint: Color, photos: [CachedPhoto])] = []
        let site = sitePhotos
        if !site.isEmpty {
            groups.append((key: "site", title: "Site", icon: "mappin.circle.fill", tint: .orange, photos: site))
        }
        for surface in viewModel.booking.surfaces {
            let surfacePhotos = viewModel.photos.filter { $0.surfaceId == surface.surfaceId }
            if !surfacePhotos.isEmpty {
                groups.append((key: surface.surfaceId.uuidString, title: surface.displayName, icon: "square.stack.3d.up", tint: .blue, photos: surfacePhotos))
            }
        }
        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", count: photoCount(for: .all), isSelected: photoFilter == .all) {
                        photoFilter = .all
                    }
                    filterChip("Site", count: photoCount(for: .site), isSelected: photoFilter == .site, tint: .orange) {
                        photoFilter = .site
                    }
                    ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                        let count = photoCount(for: .surface(surface.surfaceId))
                        filterChip(surface.displayName, count: count, isSelected: photoFilter == .surface(surface.surfaceId)) {
                            photoFilter = .surface(surface.surfaceId)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.bar)

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

            ScrollView {
                if filteredPhotos.isEmpty {
                    ContentUnavailableView(
                        "No Photos",
                        systemImage: "camera",
                        description: Text("Take photos of the installation.")
                    )
                    .padding(.top, 60)
                } else if photoFilter == .all && groupedPhotos.count > 1 {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedPhotos, id: \.key) { group in
                            PhotoGroupHeader(title: group.title, icon: group.icon, count: group.photos.count, tint: group.tint)
                            photoGrid(for: group.photos)
                        }
                    }
                } else {
                    photoGrid(for: filteredPhotos)
                        .padding(.top, 4)
                }
            }

            if viewModel.booking.visitStatus != "completed" {
                captureBar
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                let category = selectedSurfaceId == nil ? "site" : "general"
                viewModel.capturePhoto(image: image, surfaceId: selectedSurfaceId, category: category, context: modelContext)
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                let category = selectedSurfaceId == nil ? "site" : "general"
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel.capturePhoto(image: image, surfaceId: selectedSurfaceId, category: category, context: modelContext)
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
            HStack(spacing: 8) {
                Image(systemName: selectedSurfaceId == nil ? "mappin.circle.fill" : "square.stack.3d.up")
                    .foregroundStyle(selectedSurfaceId == nil ? .orange : .blue)
                    .font(.subheadline)
                Picker("Surface", selection: $selectedSurfaceId) {
                    Text("Site Photo").tag(nil as UUID?)
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

    private func filterChip(_ label: String, count: Int, isSelected: Bool, tint: Color = .blue, action: @escaping () -> Void) -> some View {
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
