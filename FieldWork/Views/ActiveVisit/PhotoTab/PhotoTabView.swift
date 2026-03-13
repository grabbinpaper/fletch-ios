import SwiftUI
import PhotosUI
import SwiftData

struct PhotoTabView: View {
    @Bindable var viewModel: ActiveVisitViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var captionText = ""
    @State private var selectedSurfaceId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Photo grid
            ScrollView {
                if viewModel.photos.isEmpty {
                    ContentUnavailableView(
                        "No Photos",
                        systemImage: "camera",
                        description: Text("Take photos of the job site and surfaces.")
                    )
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 4) {
                        ForEach(viewModel.photos, id: \.localId) { photo in
                            PhotoThumbnail(photo: photo)
                        }
                    }
                    .padding()
                }
            }

            // Capture controls
            if viewModel.booking.visitStatus != "completed" {
                VStack(spacing: 8) {
                    // Surface picker
                    HStack {
                        Text("Associate with surface:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Surface", selection: $selectedSurfaceId) {
                            Text("None").tag(nil as UUID?)
                            ForEach(viewModel.booking.surfaces, id: \.surfaceId) { surface in
                                Text(surface.displayName).tag(surface.surfaceId as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
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

                        // Photo library
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
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
                    caption: captionText.isEmpty ? nil : captionText,
                    context: modelContext
                )
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.capturePhoto(
                        image: image,
                        surfaceId: selectedSurfaceId,
                        caption: captionText.isEmpty ? nil : captionText,
                        context: modelContext
                    )
                }
                selectedPhoto = nil
            }
        }
    }
}

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
        UIImage(contentsOfFile: photo.localFilePath)
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
