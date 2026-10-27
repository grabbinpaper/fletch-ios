import SwiftUI

struct InstallSiteTabView: View {
    @Bindable var viewModel: ActiveInstallViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showCamera = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Site condition notes
                VStack(alignment: .leading, spacing: 8) {
                    Label("Site Notes", systemImage: "doc.text")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    TextField("General site observations...", text: $viewModel.siteNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                .padding()
                .sfCard()

                // Access issues
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $viewModel.accessIssues) {
                        Label("Access Issues", systemImage: "exclamationmark.triangle")
                            .font(.subheadline.bold())
                    }

                    if viewModel.accessIssues {
                        TextField("Describe access issues...", text: $viewModel.accessIssueNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                }
                .padding()
                .sfCard()

                // Tearout status
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tearout Status", systemImage: "hammer")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    Picker("Tearout", selection: $viewModel.tearoutStatus) {
                        ForEach(TearoutStatus.allCases, id: \.self) { status in
                            Text(status.label).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.tearoutStatus == .incomplete {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.sfWarning)
                            Text("Tearout is incomplete — this will be flagged for follow-up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .sfCard()

                // Site photos
                VStack(alignment: .leading, spacing: 8) {
                    Label("Site Photos", systemImage: "camera")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    let sitePhotos = viewModel.photos.filter { $0.category == "site" }
                    if sitePhotos.isEmpty {
                        Text("No site photos captured yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        let columns = [GridItem(.adaptive(minimum: 80), spacing: 4)]
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(sitePhotos, id: \.localId) { photo in
                                PhotoThumbnailView(photo: photo)
                            }
                        }
                    }

                    Button {
                        viewModel.isSiteCapture = true
                        showCamera = true
                    } label: {
                        Label("Take site photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(SFSecondaryButtonStyle())
                }
                .padding()
                .sfCard()
            }
            .padding()
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                viewModel.capturePhoto(
                    image: image,
                    category: "site",
                    context: modelContext
                )
            }
        }
    }
}

// Simple photo thumbnail for site photos
private struct PhotoThumbnailView: View {
    let photo: CachedPhoto

    var body: some View {
        Group {
            if let thumbPath = photo.thumbnailPath,
               let uiImage = UIImage(contentsOfFile: thumbPath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
