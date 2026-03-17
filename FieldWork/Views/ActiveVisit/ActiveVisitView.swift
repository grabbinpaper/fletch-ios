import SwiftUI
import SwiftData

struct ActiveVisitView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActiveVisitViewModel
    @State private var showCameraFromSurface = false

    init(booking: CachedBooking) {
        _viewModel = State(initialValue: ActiveVisitViewModel(booking: booking))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $viewModel.selectedTab) {
                ForEach(visibleTabs, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            TabView(selection: $viewModel.selectedTab) {
                MeasurementTabView(
                    viewModel: viewModel,
                    onCameraForSurface: { surfaceId in
                        viewModel.pendingSurfaceId = surfaceId
                        showCameraFromSurface = true
                    }
                )
                .tag(VisitTab.measurements)

                SiteConditionTabView(viewModel: viewModel)
                    .tag(VisitTab.site)

                PhotoTabView(viewModel: viewModel)
                    .tag(VisitTab.photos)

                ChecklistTabView(viewModel: viewModel)
                    .tag(VisitTab.checklist)

                if viewModel.booking.signatureRequired {
                    SignatureTabView(viewModel: viewModel)
                        .tag(VisitTab.signature)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom bar
            if viewModel.booking.visitStatus != "completed" {
                bottomBar
            }
        }
        .navigationTitle("Template Visit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            viewModel.configure(appState: appState)
            viewModel.loadChecklist(context: modelContext)
            viewModel.loadPhotos(context: modelContext)
        }
        .sheet(isPresented: $viewModel.showCompletionSheet) {
            CompletionView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCameraFromSurface) {
            CameraView { image in
                viewModel.capturePhoto(
                    image: image,
                    surfaceId: viewModel.pendingSurfaceId,
                    context: modelContext
                )
            }
        }
        .sheet(isPresented: $viewModel.showMarkup, onDismiss: {
            viewModel.pendingImage = nil
        }) {
            if let image = viewModel.pendingImage {
                PhotoMarkupView(
                    image: image,
                    onSave: { compositedImage, drawingData in
                        if viewModel.isSiteCapture {
                            viewModel.deferSitePhoto(image: compositedImage, annotationData: drawingData)
                        } else {
                            viewModel.savePhoto(
                                image: compositedImage,
                                annotationData: drawingData,
                                surfaceId: viewModel.pendingSurfaceId,
                                caption: viewModel.pendingCaption,
                                context: modelContext
                            )
                        }
                    },
                    onSkip: {
                        if viewModel.isSiteCapture {
                            viewModel.deferSitePhoto(image: image, annotationData: nil)
                        } else {
                            viewModel.savePhoto(
                                image: image,
                                annotationData: nil,
                                surfaceId: viewModel.pendingSurfaceId,
                                caption: viewModel.pendingCaption,
                                context: modelContext
                            )
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showSiteTagPicker) {
            SiteTagPickerSheet(
                selectedTags: $viewModel.selectedSiteTags,
                note: $viewModel.sitePhotoNote,
                onSave: {
                    viewModel.showSiteTagPicker = false
                    viewModel.savePendingSitePhoto(context: modelContext)
                },
                onCancel: {
                    viewModel.showSiteTagPicker = false
                    viewModel.savePendingSitePhoto(context: modelContext)
                }
            )
        }
    }

    private var visibleTabs: [VisitTab] {
        var tabs: [VisitTab] = [.measurements, .site, .photos, .checklist]
        if viewModel.booking.signatureRequired {
            tabs.append(.signature)
        }
        return tabs
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Progress summary
            HStack {
                ProgressView(value: viewModel.measurementProgress)
                    .tint(viewModel.measurementProgress == 1.0 ? .green : .blue)
                Text("\(Int(viewModel.measurementProgress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Button {
                viewModel.showCompletionSheet = true
            } label: {
                Text("Complete Visit")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canComplete)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }
}
